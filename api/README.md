# MailFlow API — deployment guide

PHP + IMAP backend for the **MailFlow** iOS client. Runs on Hostinger shared
hosting (Apache/LiteSpeed). No database: the mailbox `yesdaddy@celllaunch.shop`
*is* the storage.

## What's here

| File | Purpose |
|---|---|
| `messages.php` | `GET /api/messages.php` (list), `GET /api/messages.php?id=UID` (one), `DELETE /api/messages.php?id=UID` (permanent delete) |
| `send.php` | `POST /api/send.php` `{to, subject, body}` — PHPMailer over SMTP, `mail()` fallback |
| `config.php` | Env + `.env` loader, settings |
| `common.php` | CORS, JSON helpers, `X-API-Key` gate, shared errors |
| `imap_helper.php` | IMAP open, MIME body/preview extraction, delete+expunge |
| `composer.json` | Optional `phpmailer/phpmailer` dependency |
| `.env.example` | Template for `.env`; copy before configuring |

## Endpoint contract (matches `lib/api/*.dart`)

- Success list: `200 {"data": [ {id, from_email, from_name, subject, preview, date, seen}, ... ]}`
- Success single: `200 {"data": { ...same plus body... }}`
- Success send/delete: `200 {"success": true}`
- Errors: `4xx/5xx {"error": "human readable message"}`
- Auth header on every request: `X-API-Key: <MAILFLOW_API_KEY>`

## 1. Upload

Upload the contents of this `api/` directory to
`public_html/api/` in hPanel's File Manager (path: `domain/celllaunch.shop/public_html/api/`).

## 2. Configure credentials

Open hPanel → **Emails → Connect Devices** for the mailbox. You need the
IMAP/SMTP hostnames, ports and encryption as shown there.

- In hPanel **Advanced → Environment variables**, add `MAILFLOW_API_KEY`,
  `MAILFLOW_IMAP_PASS` (and `MAILFLOW_SMTP_PASS` if different), or
- Copy `.env.example` → `.env` in `api/` and fill it in. Real environment
  variables win over `.env`. The `.env` file is blocked from direct HTTP by
  `.htaccess`.

Required for receiving/reading/delete — **php-imap** must be enabled. Hostinger
shares generally ship with it; verify under hPanel **Advanced → PHP
configuration** (extension `imap`) or run a tiny test script with
`phpinfo()`. If it is missing, open a support ticket to enable `php-imap`
and `mbstring`.

Also set `MAILFLOW_API_KEY` to a long random string and rebuild the app with
the same value (see `lib/api/api_config.dart`).

## 3. Send path (SMTP vs mail())

- If `MAILFLOW_SMTP_HOST` is set **and** `vendor/autoload.php` exists (run
  `composer install --no-dev --no-interaction` in `api/` from hPanel's
  Terminal, or CLI SSH), sending uses **PHPMailer over SMTP** (recommended,
  best deliverability).
- Otherwise the API falls back to PHP's built-in `mail()`.
- If you only ever test with local addresses, either path works.

## 4. Verify

```bash
# list (should return JSON; may be 503 until php-imap + creds are real)
curl -H "X-API-Key: your-secret" https://celllaunch.shop/api/messages.php

# send
curl -X POST -H "X-API-Key: your-secret" \
  -H "Content-Type: application/json" \
  -d '{"to":"you@gmail.com","subject":"hi","body":"hello mailflow"}' \
  https://celllaunch.shop/api/send.php
```

Expect `{"error":"..."}` responses to carry the right HTTP status, never HTML.

## Security notes

- The HTTP API is the only vector into the mailbox — treat `MAILFLOW_API_KEY`
  as a password. Generate it (e.g. 32+ random chars), rebuild the app with it,
  and rotate it if it leaks.
- `.htaccess` blocks direct access to `config.php`, `common.php`,
  `imap_helper.php`, `.env`, `composer.*`, and `vendor/`. Do not loosen those
  rules.
- Sending from a domain that lacks SPF/DKIM/DMARC will land in spam or bounce.
  Set up those DNS records in hPanel's **Domains → DNS settings** for
  `celllaunch.shop` before real-world use.
- Deletes are permanent (IMAP `delete` + `expunge`) — there is no trash.

## iOS build

`flutter build ios` must run on macOS with Xcode and the bundle identifier /
signing team you have on Apple Developer. Then upload via Xcode Organizer /
Transporter to TestFlight. On Windows (this machine) only `flutter analyze`
and `flutter test` are available.