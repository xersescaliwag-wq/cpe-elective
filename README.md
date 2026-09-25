# MailFlow (a.k.a. LiquidGlass Mail)

A minimal iOS email client for the mailbox `yesdaddy@celllaunch.shop`, built
with **Flutter** and Apple's **liquid glass** rendering via
[`liquid_glass_widgets`](https://pub.dev/packages/liquid_glass_widgets).

## Stack

- App: Flutter for iOS; root is a `WidgetsApp` (no `material.dart` anywhere)
  so the whole UI stays Cupertino/glass-native.
- UI: `GlassScaffold`, `GlassAppBar`, `GlassCard`, `GlassListTile`,
  `GlassTextField`, `GlassButton`, `GlassDialog`, `GlassToast`; skeleton
  loading via [`skeletonizer`](https://pub.dev/packages/skeletonizer).
- Networking: `package:http` → `ApiClient` (`lib/api/api_client.dart`).
- Backend: PHP + `php-imap` on Hostinger shared hosting under `api/`
  (see [Deployment guide](api/README.md)). No database; the mailbox is the
  store. Receive/delete via IMAP, send via PHPMailer/SMTP or `mail()`.

## Screens

- `InboxScreen` — pull-to-refresh list, skeleton loading, error/retry.
- `MessageDetailScreen` — full body, permanent-delete confirmation dialog.
- `ComposeScreen` — to / subject / body, validation, send feedback.

## API configuration

Defaults point at `https://celllaunch.shop/api/` with a shared secret
`dev-key-change-me`. Override per build:

```sh
flutter run \
  --dart-define=MAILFLOW_API_URL=https://celllaunch.shop/api/ \
  --dart-define=MAILFLOW_API_KEY=your-secret
```

## Tests & checks

```sh
flutter analyze      # clean
flutter test         # 6 tests: model unit tests + widget tests (mock repo)
```

Widget tests use `MockMailRepository` (`lib/api/mail_repository.dart`), so no
network is required. `flutter build ios` needs macOS/Xcode.

## Layout

```
lib/
  main.dart                       # WidgetsApp root + glass theme + routes
  api/                            # ApiClient, MailMessage, repositories
  screens/                        # inbox / detail / compose
  widgets/mail_tile.dart          # inbox row
api/                              # PHP backend + deployment README
test/                             # model + widget tests
```