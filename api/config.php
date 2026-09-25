<?php
/**
 * MailFlow backend configuration.
 *
 * Secrets are loaded from environment variables, with an optional .env file
 * in this directory as a convenience fallback. Never hard-code credentials
 * in the application source. Direct HTTP access to this file is blocked by
 * the guard below and by .htaccess.
 *
 * Environment variables (see .env.example):
 *   MAILFLOW_API_KEY         Shared secret required in the X-API-Key header
 *   MAILFLOW_MAILBOX         "From" address used when sending (default yesdaddy@celllaunch.shop)
 *   MAILFLOW_IMAP_HOST       IMAP hostname from hPanel "Connect Devices" (default: imap.hostinger.com)
 *   MAILFLOW_IMAP_PORT       IMAP port (default 993)
 *   MAILFLOW_IMAP_ENCRYPTION ssl | tls | novalidate-cert (default ssl)
 *   MAILFLOW_IMAP_USER       IMAP username (default: MAILFLOW_MAILBOX)
 *   MAILFLOW_IMAP_PASS       IMAP password
 *   MAILFLOW_IMAP_MAILBOX    Optional full IMAP mailbox string override,
 *                            e.g. "{imap.hostinger.com:993/imap/ssl}INBOX"
 *   MAILFLOW_INBOX_BATCH     Max messages returned in list (default 30)
 *   MAILFLOW_SMTP_HOST       SMTP hostname (default: smtp.hostinger.com)
 *   MAILFLOW_SMTP_PORT       SMTP port (default 465)
 *   MAILFLOW_SMTP_ENCRYPTION ssl | tls (default ssl)
 *   MAILFLOW_SMTP_USER       SMTP username (default: MAILFLOW_MAILBOX)
 *   MAILFLOW_SMTP_PASS       SMTP password (default: MAILFLOW_IMAP_PASS)
 */

declare(strict_types=1);

// Block direct web access (e.g. GET /api/config.php). Safe when included.
if (
    PHP_SAPI !== 'cli'
    && isset($_SERVER['SCRIPT_NAME'])
    && basename($_SERVER['SCRIPT_NAME']) === basename(__FILE__)
) {
    http_response_code(403);
    header('Content-Type: text/plain');
    exit('Forbidden');
}

/**
 * Read a value from the environment, falling back to a simple .env file in
 * this directory (only for variables that are not already set in the real
 * environment). Returns $default when neither is present.
 */
function mf_env(string $key, string $default = ''): string
{
    static $loaded = false;
    static $dotenv = [];

    if (!$loaded) {
        $dotenv = mf_load_dotenv(__DIR__ . '/.env');
        $loaded = true;
    }

    $value = getenv($key);
    if ($value !== false && $value !== '') {
        return $value;
    }

    return isset($dotenv[$key]) && $dotenv[$key] !== '' ? $dotenv[$key] : $default;
}

/** Parse a KEY=VALUE .env file into an associative array. Never throws. */
function mf_load_dotenv(string $path): array
{
    if (!is_file($path) || !is_readable($path)) {
        return [];
    }

    $vars = [];
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines === false) {
        return [];
    }

    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        $value = trim($value);
        if ($key === '') {
            continue;
        }
        if ((str_starts_with($value, '"') && str_ends_with($value, '"'))
            || (str_starts_with($value, "'") && str_ends_with($value, "'"))
        ) {
            $value = substr($value, 1, -1);
        }
        $vars[$key] = $value;
    }

    return $vars;
}

/** Full IMAP mailbox string for imap_open(). */
function mf_imap_mailbox_string(): string
{
    $override = mf_env('MAILFLOW_IMAP_MAILBOX');
    if ($override !== '') {
        return $override;
    }

    $host = mf_env('MAILFLOW_IMAP_HOST', 'imap.hostinger.com');
    $port = mf_env('MAILFLOW_IMAP_PORT', '993');
    $enc = mf_env('MAILFLOW_IMAP_ENCRYPTION', 'ssl');

    return sprintf('{%s:%s/%s}INBOX', $host, $port, rtrim($enc, '}'));
}