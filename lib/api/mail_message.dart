
class MailMessage {
  const MailMessage({
    required this.id,
    required this.fromEmail,
    required this.fromName,
    required this.subject,
    this.preview = '',
    this.body = '',
    this.date,
    this.seen = false,
  });

  final int id;
  final String fromEmail;
  final String fromName;
  final String subject;
  final String preview;
  final String body;
  final DateTime? date;
  final bool seen;

  bool get unread => !seen;

  static String formatSubject(String subject) {
    var trimmed = subject.trim();
    if (trimmed.isEmpty) return '(no subject)';

    final prefixRegex = RegExp(r'^(re|reply):\s*', caseSensitive: false);
    bool hadPrefix = false;

    while (prefixRegex.hasMatch(trimmed)) {
      hadPrefix = true;
      trimmed = trimmed.replaceFirst(prefixRegex, '').trim();
    }

    if (trimmed.isEmpty) return 'Reply: (no subject)';
    return hadPrefix ? 'Reply: $trimmed' : trimmed;
  }

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    return MailMessage(
      id: _int(json['id']),
      fromEmail: _str(json['from_email']),
      fromName: _str(json['from_name']),
      subject: _str(json['subject'], fallback: '(no subject)'),
      preview: _str(json['preview']),
      body: _str(json['body']),
      date: _date(json['date']),
      seen: json['seen'] == true || json['seen'] == 1 || json['seen'] == '1',
    );
  }

  static String cleanBodyText(String text) {
    if (text.trim().isEmpty) return '';

    var normalized = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ')
        .replaceAll('\u200b', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    if (normalized.contains('<div class="gmail_quote"') || normalized.contains('<blockquote')) {
      normalized = normalized.split(RegExp(r'<div class="gmail_quote"|<blockquote', caseSensitive: false)).first;
    }

    normalized = normalized
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    final lines = normalized.split('\n');
    final cleaned = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final lower = trimmed.toLowerCase();

      final isQuoteHeader = trimmed.startsWith('>') ||
          (lower.startsWith('on ') && (lower.contains('wrote:') || lower.contains('<') || lower.contains('at '))) ||
          lower.startsWith('from:') ||
          lower.startsWith('sent:');

      if (isQuoteHeader) {
        if (cleaned.isNotEmpty) {
          break;
        } else {
          continue;
        }
      }
      cleaned.add(line);
    }

    final result = cleaned.join('\n').trim();
    if (result.isNotEmpty) return result;

    final unquoted = text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n')
        .where((l) => !l.trim().startsWith('>'))
        .join('\n')
        .trim();

    return unquoted.isNotEmpty ? unquoted : text.trim();
  }

  static String _str(Object? value, {String fallback = ''}) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return fallback;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      var str = trimmed;
      if (str.contains(' ') && !str.contains('T')) {
        str = str.replaceFirst(' ', 'T');
      }
      return DateTime.tryParse(str) ?? DateTime.tryParse(trimmed);
    }
    return null;
  }
}
