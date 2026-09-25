import 'package:cpeelective/api/mail_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MailMessage.fromJson', () {
    test('parses a well-formed payload', () {
      final message = MailMessage.fromJson(<String, dynamic>{
        'id': 42,
        'from_email': 'sara@example.com',
        'from_name': 'Sara',
        'subject': 'Hello',
        'preview': 'Hi there,',
        'body': 'Hi there,\n\nFull body.',
        'date': '2026-09-23T09:41:00Z',
        'seen': true,
      });

      expect(message.id, 42);
      expect(message.fromEmail, 'sara@example.com');
      expect(message.fromName, 'Sara');
      expect(message.subject, 'Hello');
      expect(message.body, contains('Full body'));
      expect(message.seen, isTrue);
      expect(message.unread, isFalse);
      expect(message.date, isNotNull);
    });

    test('defensively falls back on missing/malformed fields', () {
      final message = MailMessage.fromJson(<String, dynamic>{
        'id': 'not-an-int',
        'seen': 0,
      });

      expect(message.id, 0);
      expect(message.fromEmail, '');
      expect(message.fromName, '');
      expect(message.subject, '(no subject)');
      expect(message.preview, '');
      expect(message.body, '');
      expect(message.date, isNull);
      expect(message.seen, isFalse);
      expect(message.unread, isTrue);
    });

    test('accepts numeric and string seen flags', () {
      expect(MailMessage.fromJson(<String, dynamic>{'seen': 1}).seen, isTrue);
      expect(MailMessage.fromJson(<String, dynamic>{'seen': '1'}).seen, isTrue);
      expect(MailMessage.fromJson(<String, dynamic>{'seen': true}).seen, isTrue);
      expect(MailMessage.fromJson(<String, dynamic>{'seen': 0}).seen, isFalse);
    });
  });
}