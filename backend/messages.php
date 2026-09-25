<?php
/**
 * GET  /api/messages.php         → list of the newest messages
 * GET  /api/messages.php?id=UID  → one full message
 * DELETE /api/messages.php?id=UID → permanently delete one message
 *
 * Response parity with the Dart client (lib/api/*):
 *   - success  → 200 {"data": [...]} or {"data": {...}}
 *   - delete   → 200 {"success": true}
 *   - failure  → 4xx/5xx {"error": "human readable message"}
 */

declare(strict_types=1);

require_once __DIR__ . '/imap_helper.php';

mf_cors();
mf_require_api_key();

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

try {
    switch ($method) {
        case 'GET':
            if (isset($_GET['id'])) {
                $uid = mf_uid_from_query();
                mf_json_response(['data' => mf_get_message($uid)]);
            }
            $batch = (int) mf_env('MAILFLOW_INBOX_BATCH', '30');
            if ($batch < 1 || $batch > 100) {
                $batch = 30;
            }
            mf_json_response(['data' => mf_list_messages($batch)]);

        case 'DELETE':
            $uid = mf_uid_from_query();
            mf_delete_message($uid);
            mf_json_response(['success' => true]);

        default:
            mf_json_error('Method not allowed.', 405);
    }
} catch (MfApiException $e) {
    mf_json_error($e->getMessage(), $e->httpStatus);
} catch (Throwable $e) {
    error_log('[MailFlow] messages.php: ' . $e->getMessage());
    mf_json_error('Internal server error.', 500);
}