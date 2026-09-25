<?php
/**
 * TEMPORARY diagnosis helper for MailFlow. Auth-gated; prints NO secrets.
 * Delete when done.
 */

declare(strict_types=1);

require_once __DIR__ . '/imap_helper.php';

$key = mf_env('MAILFLOW_API_KEY', 'dev-key-change-me');
$given = $_SERVER['HTTP_X_API_KEY'] ?? '';
if ($given === '' || !hash_equals($key, $given)) {
    http_response_code(401);
    header('Content-Type: application/json');
    exit('{"error":"Unauthorized."}');
}

$envFile = __DIR__ . '/.env';
$env = mf_load_dotenv($envFile);

$out = [
    'imap_extension'  => function_exists('imap_open'),
    'env_file_exists' => is_file($envFile),
    'php_version'     => PHP_VERSION,
    'connect'         => ['ok' => false, 'error' => null],
];

if (function_exists('imap_open')) {
    try {
        $conn = @imap_open(
            mf_imap_mailbox_string(),
            mf_env('MAILFLOW_IMAP_USER', mf_env('MAILFLOW_MAILBOX', 'yesdaddy@celllaunch.shop')),
            mf_env('MAILFLOW_IMAP_PASS'),
            OP_READONLY,
            10,
            ['DISABLE_AUTHENTICATOR' => 'GSSAPI']
        );
        if ($conn !== false) {
            $out['connect']['ok'] = true;
            $uids = imap_search($conn, 'ALL', SE_UID);
            $uids = $uids === false ? [] : array_map('intval', $uids);
            rsort($uids, SORT_NUMERIC);
            $target = $uids[0] ?? 0;

            if ($target !== 0) {
                $structure = @imap_fetchstructure($conn, $target, FT_UID);
                $tree = [];
                $parts = [];
                $walk = function ($node, string $prefix) use (&$walk, &$tree, &$parts, $conn, $target) {
                    if (($node->type ?? 99) === 0) {
                        $partNo = $prefix !== '' ? $prefix : '1';
                        $charset = 'US-ASCII';
                        foreach ($node->parameters ?? [] as $param) {
                            if (strcasecmp((string) ($param->attribute ?? ''), 'charset') === 0) {
                                $charset = (string) ($param->value ?? 'UTF-8');
                                break;
                            }
                        }
                        $raw = imap_fetchbody($conn, $target, $partNo, FT_UID | FT_PEEK);
                        if (is_string($raw)) {
                            $enc = (int) ($node->encoding ?? 0);
                            if ($enc === 3) {
                                $raw = base64_decode(trim($raw), true) ?: '';
                            } elseif ($enc === 4) {
                                $raw = quoted_printable_decode($raw);
                            }
                        } else {
                            $raw = '';
                        }
                        $parts[] = [
                            'part'      => $partNo,
                            'subtype'   => strtoupper((string) ($node->subtype ?? '')),
                            'encoding'  => (int) ($node->encoding ?? 0),
                            'charset'   => $charset,
                            'ascii'     => bin2hex(substr($raw, 0, 24)),
                            'full_valid_utf8' => mb_check_encoding($raw, 'UTF-8'),
                            'full_len'  => strlen($raw),
                            'full_b64'  => base64_encode($raw),
                        ];
                        $tree[] = 'text/' . strtoupper((string) ($node->subtype ?? '?')). " part=$partNo enc={$node->encoding} charset=$charset";
                        return;
                    }
                    if (!isset($node->parts) || !is_array($node->parts)) {
                        $tree[] = 'type=' . (int) ($node->type ?? -1) . '/' . strtoupper((string) ($node->subtype ?? '?')) . ' (leaf, ignored)';
                        return;
                    }
                    $tree[] = 'multipart/' . strtoupper((string) ($node->subtype ?? '?')) . " parts=$prefix";
                    foreach ($node->parts as $i => $child) {
                        if (is_object($child)) {
                            $walk($child, $prefix !== '' ? $prefix . '.' . ($i + 1) : (string) ($i + 1));
                        }
                    }
                };
                $walk($structure, '');
                $out['target_uid'] = $target;
                $out['mime_tree']  = $tree;
                $out['text_parts'] = $parts;
            }
            imap_close($conn);
        } else {
            $out['connect']['error'] = trim((string) imap_last_error());
        }
    } catch (Throwable $e) {
        $out['connect'] = ['ok' => false, 'error' => $e->getMessage()];
    }
}

header('Content-Type: application/json; charset=utf-8');
echo json_encode($out, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);