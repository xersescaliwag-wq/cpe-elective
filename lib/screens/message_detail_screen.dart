import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/mail_message.dart';
import '../api/mail_repository.dart';

/// Full message view with liquid glass design and continuous conversation thread.
class MessageDetailScreen extends StatefulWidget {
  const MessageDetailScreen({
    super.key,
    required this.messageId,
    required this.repository,
  });

  final int messageId;
  final MailRepository repository;

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  MailMessage? _message;
  List<MailMessage> _threadMessages = const <MailMessage>[];
  bool _loading = true;
  String? _error;
  bool _deleting = false;

  bool _isReplying = false;
  bool _sendingReply = false;
  final TextEditingController _replyTextController = TextEditingController();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _replyTextController.dispose();
    super.dispose();
  }

  bool _isSameThread(MailMessage m, MailMessage target) {
    if (m.id == target.id) return true;

    String normalizeSubj(String s) {
      return MailMessage.formatSubject(s)
          .replaceAll('Reply:', '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
    }

    final targetSubj = normalizeSubj(target.subject);
    final msgSubj = normalizeSubj(m.subject);

    if (targetSubj.isNotEmpty &&
        targetSubj != 'nosubject' &&
        msgSubj.isNotEmpty &&
        msgSubj != 'nosubject') {
      if (targetSubj == msgSubj ||
          targetSubj.contains(msgSubj) ||
          msgSubj.contains(targetSubj)) {
        return true;
      }
    }

    final myMailbox = ApiConfig.mailbox.trim().toLowerCase();
    final targetEmail = target.fromEmail.trim().toLowerCase();
    final msgEmail = m.fromEmail.trim().toLowerCase();

    if (targetEmail.isNotEmpty &&
        targetEmail != myMailbox &&
        msgEmail == targetEmail) {
      return true;
    }

    if (msgEmail == myMailbox || msgEmail == 'mailflow' || msgEmail.isEmpty) {
      return true;
    }

    return false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allMessages = await widget.repository.listMessages();
      final target = allMessages.firstWhere(
            (m) => m.id == widget.messageId,
        orElse: () => allMessages.isNotEmpty
            ? allMessages.first
            : MailMessage(
          id: widget.messageId,
          fromEmail: '',
          fromName: '',
          subject: '',
          preview: '',
          body: '',
        ),
      );

      final conversation =
      allMessages.where((m) => _isSameThread(m, target)).toList();

      conversation.sort((a, b) {
        if (a.date == null) return -1;
        if (b.date == null) return 1;
        return a.date!.compareTo(b.date!);
      });

      if (!mounted) return;
      setState(() {
        _message = target;
        _threadMessages =
        conversation.isNotEmpty ? conversation : <MailMessage>[target];
        _loading = false;
      });
    } on ApiException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('Something went wrong while loading this conversation.');
    }
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _loading || _isReplying || _sendingReply) return;
    try {
      final allMessages = await widget.repository.listMessages();
      if (!mounted || _message == null) return;

      final target = _message!;
      final conversation =
      allMessages.where((m) => _isSameThread(m, target)).toList();

      conversation.sort((a, b) {
        if (a.date == null) return -1;
        if (b.date == null) return 1;
        return a.date!.compareTo(b.date!);
      });

      if (!mounted) return;
      setState(() {
        _threadMessages =
        conversation.isNotEmpty ? conversation : <MailMessage>[target];
      });
    } catch (_) {}
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await GlassDialog.show<bool>(
      context: context,
      title: 'Delete message?',
      message: 'This permanently removes the email from ${ApiConfig.mailbox}.',
      settings: const LiquidGlassSettings(
        chromaticAberration: 0.12,
        thickness: 28,
        blur: 16,
      ),
      actions: <GlassDialogAction>[
        GlassDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlassDialogAction(
          label: 'Delete',
          isDestructive: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.repository.deleteMessage(widget.messageId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      GlassToast.show(
        context,
        message: error is ApiException ? error.message : 'Could not delete the message.',
        type: GlassToastType.error,
      );
    }
  }

  Future<void> _handleReplyAction() async {
    final message = _message;
    if (message == null) return;

    final recipient = message.fromEmail.isNotEmpty
        ? message.fromEmail
        : message.fromName;

    if (!_isReplying) {
      setState(() {
        _isReplying = true;
      });
      return;
    }

    final replyBody = _replyTextController.text.trim();
    if (replyBody.isEmpty) {
      GlassToast.show(
        context,
        message: 'Please enter a reply message.',
        type: GlassToastType.error,
      );
      return;
    }

    final subject = _formatReplySubject(message.subject);

    final now = DateTime.now();
    final senderHeader = message.fromName.isNotEmpty
        ? '${message.fromName} <${message.fromEmail}>'
        : message.fromEmail;
    final quotedBody =
    message.body.trim().isNotEmpty ? message.body : message.preview;
    final fullOutgoingBody =
        '$replyBody\n\nOn ${_formatFull(message.date ?? now)} $senderHeader wrote:\n> ${quotedBody.replaceAll('\n', '\n> ')}';

    setState(() => _sendingReply = true);
    try {
      await widget.repository.sendMessage(
        to: recipient,
        subject: subject,
        body: fullOutgoingBody,
      );
      if (!mounted) return;

      _replyTextController.clear();
      setState(() {
        _isReplying = false;
        _sendingReply = false;
      });

      GlassToast.show(
        context,
        message: 'Reply sent to $recipient',
        type: GlassToastType.info,
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendingReply = false);
      GlassToast.show(
        context,
        message: error is ApiException ? error.message : 'Could not send reply.',
        type: GlassToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: _buildBackground(),
      appBar: GlassAppBar(
        leading: GlassIconButton(
          key: const ValueKey('message-back'),
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Message',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: <Widget>[
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 40,
              height: 40,
              child: GestureDetector(
                key: const ValueKey('message-delete'),
                onTap: !_deleting && _message != null ? _confirmDelete : null,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null || _loading || _message == null) {
      return const _DetailSkeleton();
    }

    final message = _message!;
    final recipient = message.fromEmail.isNotEmpty
        ? message.fromEmail
        : message.fromName;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.paddingOf(context).top + 56,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        Text(
          MailMessage.formatSubject(message.subject),
          style: const TextStyle(
            color: Color(0xFFF2F5FF),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 16),
        ..._threadMessages.map((msg) {
          final isMine = msg.fromEmail == ApiConfig.mailbox || msg.fromName == 'MailFlow';
          final rawBody = msg.body.trim().isNotEmpty ? msg.body : msg.preview;
          final displayBody = MailMessage.cleanBodyText(rawBody);
          final finalBody = displayBody.isNotEmpty
              ? displayBody
              : (msg.preview.trim().isNotEmpty
              ? msg.preview.trim()
              : (msg.body.trim().isNotEmpty ? msg.body.trim() : '(No text content)'));

          final parsed = _parseEmailQuotes(finalBody);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              shape: const LiquidRoundedRectangle(borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(initial: _initial(isMine ? 'Me' : (msg.fromName.isEmpty ? msg.fromEmail : msg.fromName))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMine ? 'You' : (msg.fromName.isEmpty ? msg.fromEmail : msg.fromName),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: CupertinoColors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMine ? 'To: ${msg.fromEmail.isNotEmpty ? msg.fromEmail : recipient}' : msg.fromEmail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            if (msg.date != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatFull(msg.date!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF60A5FA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (parsed.quoteHeader != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000).withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(6),
                          topLeft: Radius.circular(6),
                        ),
                        border: const Border(
                          left: BorderSide(
                            color: Color(0xFF60A5FA),
                            width: 3.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parsed.quoteHeader!,
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                          ),
                          if (parsed.quoteBody != null && parsed.quoteBody!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              parsed.quoteBody!,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    parsed.replyText,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_isReplying) ...[
          GlassCard(
            padding: const EdgeInsets.all(16),
            shape: const LiquidRoundedRectangle(borderRadius: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $recipient',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () {
                        setState(() {
                          _isReplying = false;
                        });
                      },
                      child: const FaIcon(
                        FontAwesomeIcons.xmark,
                        size: 16,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassFormField(
                  label: 'Your Reply',
                  child: GlassTextArea(
                    controller: _replyTextController,
                    placeholder: 'Type your reply message here…',
                    minLines: 4,
                    maxLines: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        GlassButton.custom(
          width: double.infinity,
          height: 52,
          shape: const LiquidRoundedRectangle(borderRadius: 16),
          glowColor: CupertinoColors.activeBlue.withValues(alpha: 0.4),
          glowRadius: 1.2,
          enabled: !_sendingReply,
          onTap: _sendingReply ? () {} : _handleReplyAction,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_sendingReply)
                const _AnimatedSendingIcon()
              else
                FaIcon(
                  _isReplying ? FontAwesomeIcons.paperPlane : FontAwesomeIcons.reply,
                  size: 18,
                  color: CupertinoColors.white,
                ),
              const SizedBox(width: 10),
              Text(
                _sendingReply
                    ? 'Sending Reply…'
                    : (_isReplying ? 'Send Reply' : 'Reply'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _ParsedEmailContent _parseEmailQuotes(String rawContent) {
    final quoteRegex = RegExp(r'(On\s+[\s\S]+?wrote:)', caseSensitive: false);
    final match = quoteRegex.firstMatch(rawContent);

    if (match != null) {
      final replyPart = rawContent.substring(0, match.start).trim();
      final headerPart = match.group(1)?.trim();
      String remaining = rawContent.substring(match.end).trim();

      final secondaryQuote = RegExp(r'On\s+[\s\S]+?wrote:', caseSensitive: false).firstMatch(remaining);
      if (secondaryQuote != null) {
        remaining = remaining.substring(0, secondaryQuote.start).trim();
      }

      final cleanedQuoteLines = remaining
          .replaceAll('>', '\n')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      return _ParsedEmailContent(
        replyText: replyPart.isNotEmpty ? replyPart : '(No message body)',
        quoteHeader: headerPart,
        quoteBody: cleanedQuoteLines.isNotEmpty ? cleanedQuoteLines.join('\n') : null,
      );
    }

    return _ParsedEmailContent(replyText: rawContent.trim());
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  static String _formatFull(DateTime date) {
    final phtDate = date.toUtc().add(const Duration(hours: 8));
    final hour = phtDate.hour % 12 == 0 ? 12 : phtDate.hour % 12;
    final mm = phtDate.minute.toString().padLeft(2, '0');
    final period = phtDate.hour >= 12 ? 'PM' : 'AM';
    return '${phtDate.year}/${phtDate.month}/${phtDate.day} · $hour:$mm $period';
  }

  static String _formatReplySubject(String originalSubject) {
    return MailMessage.formatSubject(originalSubject);
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/arigato.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: const Color(0xFF090B10));
          },
        ),
        Container(
          color: const Color(0xFF000000).withValues(alpha: 0.35),
        ),
      ],
    );
  }
}

class _ParsedEmailContent {
  final String replyText;
  final String? quoteHeader;
  final String? quoteBody;

  _ParsedEmailContent({
    required this.replyText,
    this.quoteHeader,
    this.quoteBody,
  });
}

class _AnimatedSendingIcon extends StatefulWidget {
  const _AnimatedSendingIcon();

  @override
  State<_AnimatedSendingIcon> createState() => _AnimatedSendingIconState();
}

class _AnimatedSendingIconState extends State<_AnimatedSendingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const FaIcon(
        FontAwesomeIcons.paperPlane,
        size: 18,
        color: CupertinoColors.white,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Plain at malinis na skeleton para sa message details:
/// Diretso mga Bone widget sa loob ng simpleng flat container
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      containersColor: CupertinoColors.transparent,
      ignoreContainers: true,
      effect: const ShimmerEffect(
        baseColor: Color(0x1AFFFFFF),
        highlightColor: Color(0x40FFFFFF),
        duration: Duration(milliseconds: 1200),
      ),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16 + MediaQuery.paddingOf(context).top + 56,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          // Subject line placeholder
          const Bone.text(
            width: 260,
            fontSize: 22,
          ),
          const SizedBox(height: 8),
          const Bone.text(
            width: 170,
            fontSize: 16,
          ),
          const SizedBox(height: 20),

          // Sender card placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0x15FFFFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Bone.circle(size: 42),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Bone.text(width: 140, fontSize: 15),
                      SizedBox(height: 6),
                      Bone.text(width: 190, fontSize: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Message body content placeholder
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0x15FFFFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(width: double.infinity, fontSize: 14),
                SizedBox(height: 10),
                Bone.text(width: double.infinity, fontSize: 14),
                SizedBox(height: 10),
                Bone.text(width: 220, fontSize: 14),
                SizedBox(height: 16),
                Bone.text(width: double.infinity, fontSize: 14),
                SizedBox(height: 10),
                Bone.text(width: 180, fontSize: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}