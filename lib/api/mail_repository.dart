import 'api_client.dart';
import 'mail_message.dart';

/// Data access seam for the mail screens.
///
/// Screens depend on this interface, never on the transport directly. That
/// keeps the UI testable offline: a [MockMailRepository] can stand in for the
/// live [RemoteMailRepository] in widget tests and demos.
abstract class MailRepository {
  Future<List<MailMessage>> listMessages();

  Future<MailMessage?> getMessage(int id);

  Future<void> sendMessage({
    required String to,
    required String subject,
    required String body,
  });

  Future<void> deleteMessage(int id);
}

/// Talks to the PHP API on `celllaunch.shop` via [ApiClient].
class RemoteMailRepository implements MailRepository {
  RemoteMailRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<MailMessage>> listMessages() async {
    final json = await _api.get('messages.php');
    final data = json['data'];
    if (data is List) {
      return data
          .map((e) => MailMessage.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    }
    return const <MailMessage>[];
  }

  @override
  Future<MailMessage?> getMessage(int id) async {
    final json = await _api.get('messages.php', query: <String, String>{
      'id': '$id'
    });
    final data = json['data'];
    if (data is Map) {
      return MailMessage.fromJson(data.cast<String, dynamic>());
    }
    return null;
  }

  @override
  Future<void> sendMessage({
    required String to,
    required String subject,
    required String body,
  }) async {
    await _api.post('send.php', body: <String, dynamic>{
      'to': to,
      'subject': subject,
      'body': body,
    });
  }

  @override
  Future<void> deleteMessage(int id) async {
    await _api.delete('messages.php', query: <String, String>{'id': '$id'});
  }
}

/// In-memory repository for offline development, demos and widget tests.
class MockMailRepository implements MailRepository {
  MockMailRepository({List<MailMessage>? seed})
      : _messages = List<MailMessage>.of(seed ?? _defaultSeed());

  final List<MailMessage> _messages;
  int _nextId = 1000;

  static List<MailMessage> _defaultSeed() {
    final now = DateTime.now();
    return <MailMessage>[
      MailMessage(
        id: 1,
        fromEmail: 'hello@flutter.dev',
        fromName: 'Flutter Team',
        subject: 'Welcome to Flutter 3.44',
        preview: 'We are excited to announce the latest stable release of Flutter.',
        body:
            'Hey there,\n\nWe are excited to announce the latest stable release '
            'of Flutter with a brand new liquid glass rendering engine.\n\n'
            'Check out the release notes for everything that changed.\n\n'
            '— The Flutter Team',
        date: now.subtract(const Duration(minutes: 12)),
        seen: false,
      ),
      MailMessage(
        id: 2,
        fromEmail: 'noreply@hostinger.com',
        fromName: 'Hostinger',
        subject: 'Your mailbox yesdaddy@celllaunch.shop is ready',
        preview: 'Your hosting account is live. Configure devices using the details below…',
        body:
            'Hi,\n\nYour hosting account and mailbox are live. Use the "Connect '
            'Devices" screen in hPanel to grab the IMAP/SMTP details for your '
            'mail client.\n\nRegards,\nHostinger Support',
        date: now.subtract(const Duration(hours: 2)),
        seen: false,
      ),
      MailMessage(
        id: 3,
        fromEmail: 'notifications@apple.com',
        fromName: 'Apple Developer',
        subject: 'TestFlight: new build available',
        preview: 'A new build of your app is ready for internal testing…',
        body: 'A new build of your app is available for internal testing on TestFlight.\n\n– Apple Developer',
        date: now.subtract(const Duration(days: 1)),
        seen: true,
      ),
      MailMessage(
        id: 4,
        fromEmail: 'team@github.com',
        fromName: 'GitHub',
        subject: '[cpeelective] 2 new comments on your pull request',
        preview: 'reviewer-bot commented · resolved conversation',
        body: 'reviewer-bot commented on your pull request:\n\nPlease add tests for the new API client.',
        date: now.subtract(const Duration(days: 3)),
        seen: true,
      ),
    ];
  }

  @override
  Future<List<MailMessage>> listMessages() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return List<MailMessage>.of(_messages.reversed);
  }

  @override
  Future<MailMessage?> getMessage(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  @override
  Future<void> sendMessage({
    required String to,
    required String subject,
    required String body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _messages.add(MailMessage(
      id: _nextId++,
      fromEmail: 'yesdaddy@celllaunch.shop',
      fromName: 'MailFlow',
      subject: subject,
      preview: body.length <= 90 ? body : body.substring(0, 90),
      body: body,
      date: DateTime.now(),
      seen: true,
    ));
  }

  @override
  Future<void> deleteMessage(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _messages.removeWhere((message) => message.id == id);
  }
}