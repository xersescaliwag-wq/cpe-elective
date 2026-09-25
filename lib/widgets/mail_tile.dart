import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../api/mail_message.dart';

/// One glass tile row in the inbox list matching the Notification GlassContainer styling.
class MailTile extends StatelessWidget {
  const MailTile({super.key, required this.message, this.onTap});

  final MailMessage message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      shape: const LiquidRoundedRectangle(borderRadius: 18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(
              initial: _initial(message.fromName.isEmpty ? message.fromEmail : message.fromName),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          message.subject.isEmpty ? 'Loading subject line' : MailMessage.formatSubject(message.subject),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: message.unread ? const Color(0xFFF2F5FF) : const Color(0xFFB9C0CC),
                            fontWeight: message.unread ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _formatDate(message.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: message.unread ? const Color(0xFF6C8CFF) : CupertinoColors.systemGrey,
                            fontSize: 12,
                            fontWeight: message.unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _subtitle(message),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                      ),
                      if (message.unread && message.id != -1) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4D7CFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(MailMessage message) {
    final sender = message.fromName.isEmpty ? message.fromEmail : message.fromName;
    final bodyContent = message.body.isNotEmpty ? message.body : message.preview;
    final cleanContent = MailMessage.cleanBodyText(bodyContent);
    if (cleanContent.isEmpty) return sender;
    return '$sender — $cleanContent';
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '04:20 PM';
    // Format strictly in (UTC+08:00) Philippines / Singapore / Kuala Lumpur timezone
    final phtDate = date.toUtc().add(const Duration(hours: 8));
    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = DateTime(phtNow.year, phtNow.month, phtNow.day);
    final day = DateTime(phtDate.year, phtDate.month, phtDate.day);
    final days = today.difference(day).inDays;

    final hour = phtDate.hour % 12 == 0 ? 12 : phtDate.hour % 12;
    final mm = phtDate.minute.toString().padLeft(2, '0');
    final period = phtDate.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$mm $period';

    if (days <= 0) {
      return timeStr;
    }
    if (days == 1) return 'Yesterday';
    return '${phtDate.month}/${phtDate.day}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withValues(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Text(
        initial,
        style: const TextStyle(color: Color(0xFFE9EEFF), fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
