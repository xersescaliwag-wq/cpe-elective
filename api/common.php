<?php
/**
 * Shared helpers for the MailFlow API: CORS/preflight handling, JSON
 * responses, the API-key gate and the typed API exception. Direct HTTP access
 * is blocked.
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

require_once __DIR__ . '/config.php';

/** Thrown for any recoverable backend error; carries the HTTP status. */
final class MfApiException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $httpStatus = 500
    ) {
        parent::__construct($message);
    }
}

/**
 * Emit CORS headers and terminate preflight OPTIONS requests. Native iOS
 * apps do not need CORS, but this keeps curl / browser debugging painless.
 */
function mf_cors(): void
{
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Accept, X-API-Key');
    header('Access-Control-Max-Age: 86400');

    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function mf_json_response(array $payload, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
    );
    exit;
}

function mf_json_error(string $message, int $status = 500): never
{
    mf_json_response(['error' => $message], $status);
}

/** Rejects the request when the X-API-Key header does not match the secret. */
function mf_require_api_key(): void
{
    $key = getenv('MAILFLOW_API_KEY');
    if ($key === false || $key === '') {
        $key = mf_env('MAILFLOW_API_KEY', 'dev-key-change-me');
    }

    $given = $_SERVER['HTTP_X_API_KEY'] ?? '';

    if ($given === '' || !hash_equals($key, $given)) {
        mf_json_error('Unauthorized.', 401);
    }
}

/**
 * Resolve a ?id= query value into a positive integer UID, or raise a 400.
 * Missing/non-numeric/<=0 ids are all rejected up front.
 */
function mf_uid_from_query(): int
{
    $raw = trim((string) ($_GET['id'] ?? ''));
    if ($raw === '' || !ctype_digit($raw)) {
        throw new MfApiException('Missing or invalid message id.', 400);
    }
    return (int) $raw;
}