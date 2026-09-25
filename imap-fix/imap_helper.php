<?php
/**
 * IMAP helpers for the MailFlow backend: connection handling, header
 * parsing, MIME body/preview extraction and permanent deletion. Direct HTTP
 * access is blocked; use via messages.php.
 *
 * UID semantics throughout: every operation addresses messages by IMAP UID
 * (FT_UID), and reads use FT_PEEK so opening a message never flips its
 * \Seen flag behind the user's back.
 */

declare(strict_types=1);

if (
    PHP_SAPI !== 'cli'
    && isset($_SERVER['SCRIPT_NAME'])
    && basename($_SERVER['SCRIPT_NAME']) === basename(__FILE__)
) {
    http_response_code(403);
    header('Content-Type: text/plain');
    exit('Forbidden');
}

require_once __DIR__ . '/common.php';

/** Seconds to wait for the IMAP connection / command round trips. */
final class MfImap
{
    public const TIMEOUT = 10;

    /** Decode an encoded-word header (MIME =?..?= ) to UTF-8, safely. */
    public static function decode(string $text): string
    {
        return imap_utf8($text);
    }

    /** Normalise an RFC2822 header date to ISO-8601 (Dart DateTime.parse). */
    public static function isoDate(string $rfc): ?string
    {
        $ts = strtotime($rfc);
        return $ts === false ? null : date('c', $ts);
    }

    /** Split "Name <a@b.c>" into ['name' => ..., 'email' => ...]. */
    public static function parseAddress(string $raw): array
    {
        $raw = trim($raw);
        $name = '';
        $email = $raw;

        if (preg_match('/^(.*?)[<]([^<>\s]+)[>]$/s', $raw, $m)) {
            $name = trim(trim($m[1]), " \t\"'");
            $email = trim($m[2]);
        }
        if ($email === '' && $name !== '') {
            $email = $name;
            $name = '';
        }

        return ['name' => $name, 'email' => $email];
    }

    /** Convert a body chunk from its declared charset to UTF-8. */
    public static function toUtf8(string $text, string $charset = 'UTF-8'): string
    {
        $charset = strtoupper(trim($charset !== '' ? $charset : 'UTF-8'));
        if ($charset === 'UTF-8' || $charset === 'US-ASCII' || $charset === 'ASCII') {
            return $text;
        }
        if (function_exists('mb_convert_encoding')) {
            return mb_convert_encoding($text, 'UTF-8', $charset);
        }
        if (function_exists('iconv')) {
            $converted = @iconv($charset, 'UTF-8//IGNORE', $text);
            return $converted === false ? $text : $converted;
        }
        return $text;
    }
}

/**
 * Open the mailbox. Returns the connection or throws a 503 MfApiException.
 *
 * @param bool $readonly Open with OP_READONLY (list reads only).
 */
function mf_imap_open(bool $readonly = false)
{
    if (!function_exists('imap_open')) {
        throw new MfApiException(
            'The PHP IMAP extension (php-imap) is not enabled on this server.',
            503
        );
    }

    $mailbox = mf_imap_mailbox_string();
    $user = mf_env('MAILFLOW_IMAP_USER');
    if ($user === '') {
        $user = mf_env('MAILFLOW_MAILBOX', 'yesdaddy@celllaunch.shop');
    }
    $pass = mf_env('MAILFLOW_IMAP_PASS');
    if ($pass === '') {
        throw new MfApiException(
            'Mailbox credentials are not configured (MAILFLOW_IMAP_PASS).',
            503
        );
    }

    $flags = $readonly ? OP_READONLY : 0;

    $conn = @imap_open(
        $mailbox,
        $user,
        $pass,
        $flags,
        MfImap::TIMEOUT,
        ['DISABLE_AUTHENTICATOR' => 'GSSAPI']
    );

    if ($conn === false) {
        $reason = trim((string) imap_last_error());
        $reason = $reason !== '' ? ' ' . $reason : '';
        throw new MfApiException(
            'Could not connect to the mailbox.' . $reason,
            503
        );
    }

    return $conn;
}

/**
 * Walk a MIME structure and collect the part numbers of text parts,
 * splitting out plain vs html. $prefix is the parent part's number.
 */
function mf_walk_structure(stdClass $structure, string $prefix, array &$plain, array &$html): void
{
    if (($structure->type ?? 99) === 0) {
        // A text part. Its IMAP fetch number is the accumulated prefix
        // (a leading "1" for single-part bodies).
        $partNo = $prefix !== '' ? $prefix : '1';
        $subtype = strtoupper((string) ($structure->subtype ?? ''));
        $entry = [
            'part'      => $partNo,
            'encoding'  => (int) ($structure->encoding ?? 0),
            'charset'   => 'US-ASCII',
        ];
        // Prefer the explicit charset parameter, when the part declares one.
        foreach ($structure->parameters ?? [] as $param) {
            if (strcasecmp((string) ($param->attribute ?? ''), 'charset') === 0) {
                $entry['charset'] = (string) ($param->value ?? 'UTF-8');
                break;
            }
        }
        if ($subtype === 'HTML') {
            $html[] = $entry;
        } else {
            $plain[] = $entry;
        }
        return;
    }

    if (!isset($structure->parts) || !is_array($structure->parts)) {
        return;
    }

    foreach ($structure->parts as $i => $part) {
        if (!is_object($part)) {
            continue;
        }
        $childNo = $prefix !== ''
            ? $prefix . '.' . (string) ($i + 1)
            : (string) ($i + 1);
        mf_walk_structure($part, $childNo, $plain, $html);
    }
}

/** Fetch and decode a single MIME part's text content. */
function mf_fetch_part(
     $imap,
    int $uid,
    string $partNo,
    int $encoding,
    string $charset
): string {
    $body = imap_fetchbody($imap, $uid, $partNo, FT_UID | FT_PEEK);
    if ($body === false) {
        return '';
    }

    switch ($encoding) {
        case 3: // base64
            $body = base64_decode(trim((string) $body), true);
            break;
        case 4: // quoted-printable
            $body = quoted_printable_decode((string) $body);
            break;
    }

    return MfImap::toUtf8((string) $body, $charset);
}

/**
 * Extract the readable text of a message as one UTF-8 string (plain text
 * preferred; HTML stripped as a fallback).
 */
function mf_fetch_text(
     $imap,
    int $uid,
    int $maxLength = 300000
): string {
    $structure = @imap_fetchstructure($imap, $uid, FT_UID);
    if ($structure === false || !is_object($structure)) {
        // Fallback: treat the whole message as a single plain part.
        $body = imap_body($imap, $uid, FT_UID | FT_PEEK);
        if ($body === false) {
            return '';
        }
        return MfImap::toUtf8((string) $body);
    }

    $plain = [];
    $html = [];
    mf_walk_structure($structure, '', $plain, $html);

    $text = '';
    foreach (($plain !== [] ? $plain : $html) as $part) {
        $chunk = mf_fetch_part(
            $imap,
            $uid,
            $part['part'],
            $part['encoding'],
            $part['charset']
        );
        $text .= $chunk . "\n";
    }

    if ($html !== [] && $plain === []) {
        $text = strip_tags($text);
        $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    return mb_substr($text, 0, $maxLength, 'UTF-8');
}

/** Collapse a body into a one-line preview capped at 160 chars. */
function mf_preview(string $body): string
{
    $preview = preg_replace('/\s+/u', ' ', trim($body)) ?? '';
    $preview = trim($preview);
    if (mb_strlen($preview, 'UTF-8') > 160) {
        $preview = mb_substr($preview, 0, 157, 'UTF-8') . '…';
    }
    return $preview;
}

/** Row for the inbox list endpoint. */
function mf_summary(
     $imap,
    int $uid,
    bool $withBody = false
): array {
    $overview = imap_fetch_overview($imap, (string) $uid, FT_UID);
    $header = $overview[0] ?? null;
    if ($header === null) {
        throw new MfApiException('Message not found.', 404);
    }

    $from = MfImap::parseAddress((string) ($header->from ?? ''));
    $to = MfImap::parseAddress((string) ($header->to ?? ''));
    $subject = MfImap::decode((string) ($header->subject ?? ''));
    if ($subject === '') {
        $subject = '(no subject)';
    }

    $row = [
        'id'         => $uid,
        'from_email' => $from['email'],
        'from_name'  => $from['name'],
        'to_email'   => $to['email'],
        'subject'    => $subject,
        'preview'    => '',
        'body'       => '',
        'date'       => MfImap::isoDate((string) ($header->date ?? '')),
        'seen'       => !empty($header->seen),
    ];

    $body = mf_fetch_text($imap, $uid);
    $row['preview'] = mf_preview($body);
    if ($withBody) {
        $row['body'] = $body;
    }

    return $row;
}

/** List the newest $limit messages, newest first. */
function mf_list_messages(int $limit): array
{
    $imap = mf_imap_open(true);
    try {
        $uids = imap_search($imap, 'ALL', SE_UID);
        if ($uids === false || $uids === []) {
            return [];
        }

        $uids = array_map('intval', $uids);
        rsort($uids, SORT_NUMERIC);

        $messages = [];
        foreach (array_slice($uids, 0, $limit) as $uid) {
            try {
                $messages[] = mf_summary($imap, $uid);
            } catch (MfApiException $e) {
                continue; // a vanished message must not break the whole list
            }
        }
        return $messages;
    } finally {
        imap_close($imap);
    }
}

/** Fetch one full message by UID. */
function mf_get_message(int $uid): array
{
    $imap = mf_imap_open(true);
    try {
        return mf_summary($imap, $uid, true);
    } finally {
        imap_close($imap);
    }
}

/** Permanently delete one message by UID (delete + expunge). */
function mf_delete_message(int $uid): void
{
    $imap = mf_imap_open(false);
    try {
        $overview = imap_fetch_overview($imap, (string) $uid, FT_UID);
        if (empty($overview[0])) {
            throw new MfApiException('Message not found.', 404);
        }

        if (!imap_delete($imap, (string) $uid, FT_UID)) {
            throw new MfApiException(
                'Could not delete the message: ' . trim((string) imap_last_error()),
                500
            );
        }
        imap_expunge($imap);
    } finally {
        imap_close($imap);
    }
}