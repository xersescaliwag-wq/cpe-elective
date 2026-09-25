<?php
/**
 * POST /api/send.php — send an email from the mailbox.
 *
 * Request body (JSON): { "to": "...", "subject": "...", "body": "..." }
 *
 * Strategy:
 *   1. If the PHPMailer vendor autoload is present (composer install ran)
 *      AND SMTP settings are configured, send via PHPMailer over SMTP.
 *   2. Otherwise fall back to PHP's mail() with hardened headers.
 *
 * Response parity with the Dart client:
 *   - success → 200 {"success": true}
 *   - failure → 4xx/5xx {"error": "human readable message"}
 */

declare(strict_types=1);

require_once __DIR__ . '/common.php';

mf_cors();
mf_require_api_key();

try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        mf_json_error('Method not allowed.', 405);
    }

    $raw = file_get_contents('php://input');
    $payload = json_decode($raw ?: '', true);
    if (!is_array($payload)) {
        mf_json_error('Request body must be valid JSON.', 400);
    }

    // --- Validate & sanitize ------------------------------------------------

    $to = trim((string) ($payload['to'] ?? ''));
    $to = str_replace(["\r", "\n", "\0"], '', $to); // header-injection guard
    if ($to === '' || !filter_var($to, FILTER_VALIDATE_EMAIL)) {
        mf_json_error('Enter a valid recipient email address.', 400);
    }

    $subject = trim((string) ($payload['subject'] ?? ''));
    $subject = str_replace(["\r", "\n", "\0"], '', $subject);
    $subject = mb_substr($subject, 0, 998, 'UTF-8');

    $body = (string) ($payload['body'] ?? '');
    $body = trim($body);
    if ($body === '') {
        mf_json_error('The message body is empty.', 400);
    }
    $body = mb_substr($body, 0, 300000, 'UTF-8');

    $mailbox = mf_env('MAILFLOW_MAILBOX', 'yesdaddy@celllaunch.shop');

    // --- Send ----------------------------------------------------------------

    $sent = class_exists('PHPMailer\\PHPMailer\\PHPMailer')
        && mf_env('MAILFLOW_SMTP_HOST') !== ''
        ? mf_send_phpmailer($to, $subject, $body, $mailbox)
        : mf_send_mail($to, $subject, $body, $mailbox);

    if (!$sent) {
        mf_json_error('Could not send the message. Please try again.', 502);
    }

    mf_json_response(['success' => true]);
} catch (MfApiException $e) {
    mf_json_error($e->getMessage(), $e->httpStatus);
} catch (Throwable $e) {
    error_log('[MailFlow] send.php: ' . $e->getMessage());
    mf_json_error('Internal server error.', 500);
}

/**
 * Send via PHPMailer over SMTP. Requires vendor/autoload.php next to the API.
 */
function mf_send_phpmailer(string $to, string $subject, string $body, string $from): bool
{
    $autoload = __DIR__ . '/vendor/autoload.php';
    if (!is_file($autoload)) {
        return false;
    }
    require_once $autoload;

    if (!class_exists('PHPMailer\\PHPMailer\\PHPMailer')) {
        return false;
    }

    $mail = new \PHPMailer\PHPMailer\PHPMailer(true);

    $mail->isSMTP();
    $mail->Host = mf_env('MAILFLOW_SMTP_HOST');
    $mail->Port = (int) mf_env('MAILFLOW_SMTP_PORT', '587');
    $enc = strtolower(mf_env('MAILFLOW_SMTP_ENCRYPTION', 'tls'));
    $mail->SMTPSecure = $enc === 'tls'
        ? \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS
        : \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_SMTPS;
    $mail->SMTPAuth = true;
    $mail->Username = mf_env('MAILFLOW_SMTP_USER');
    if ($mail->Username === '') {
        $mail->Username = $from;
    }
    $mail->Password = mf_env('MAILFLOW_SMTP_PASS');
    if ($mail->Password === '') {
        $mail->Password = mf_env('MAILFLOW_IMAP_PASS');
    }
    $mail->CharSet = \PHPMailer\PHPMailer\PHPMailer::CHARSET_UTF8;
    $mail->Timeout = 15;

    $mail->setFrom($from, 'MailFlow');
    $mail->addAddress($to);
    $mail->Subject = $subject;
    $mail->Body = $body;

    return $mail->send();
}

/**
 * Send via PHP's built-in mail(). Header-only injection is already handled
 * by the caller's CR/LF stripping; From is pinned to the mailbox.
 */
function mf_send_mail(string $to, string $subject, string $body, string $from): bool
{
    $headers = [
        'From: MailFlow <' . $from . '>',
        'Reply-To: ' . $from,
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
        'X-Mailer: MailFlow/1.0',
    ];

    return @mail($to, $subject, $body, implode("\r\n", $headers));
}