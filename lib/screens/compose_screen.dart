import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../api/api_client.dart';
import '../api/mail_repository.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.repository,
    this.initialTo,
    this.initialSubject,
    this.initialBody,
  });

  final MailRepository repository;
  final String? initialTo;
  final String? initialSubject;
  final String? initialBody;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late final TextEditingController _toController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _toController = TextEditingController(text: widget.initialTo ?? '');
    _subjectController = TextEditingController(text: widget.initialSubject ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _toController.text.trim();
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (to.isEmpty) return _notify('Enter a recipient address.');
    if (!to.contains('@')) return _notify('Enter a valid email address.');
    if (body.isEmpty) return _notify('The message body is empty.');

    setState(() => _sending = true);
    try {
      await widget.repository.sendMessage(to: to, subject: subject, body: body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _notify(error is ApiException ? error.message : 'Could not send the message.');
    }
  }

  void _notify(String message) {
    GlassToast.show(context, message: message, type: GlassToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.initialTo != null ? 'Reply' : 'New Message';

    return GlassScaffold(
      background: _buildBackground(),
      appBar: GlassAppBar(
        leading: GlassIconButton(
          key: const ValueKey('compose-back'),
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            20 + MediaQuery.paddingOf(context).top + 56,
            16,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            GlassCard(
              padding: const EdgeInsets.all(16),
              shape: const LiquidRoundedRectangle(borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassFormField(
                    label: 'To',
                    child: GlassTextField(
                      controller: _toController,
                      placeholder: 'recipient@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassFormField(
                    label: 'Subject',
                    child: GlassTextField(
                      controller: _subjectController,
                      placeholder: 'Subject line',
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassFormField(
                    label: 'Message',
                    child: GlassTextArea(
                      controller: _bodyController,
                      placeholder: 'Type your message here…',
                      minLines: 8,
                      maxLines: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassButton.custom(
              width: double.infinity,
              height: 54,
              shape: const LiquidRoundedRectangle(borderRadius: 16),
              glowColor: CupertinoColors.activeBlue.withValues(alpha: 0.5),
              glowRadius: 1.3,
              enabled: !_sending,
              onTap: _sending ? () {} : _send,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_sending)
                    const _AnimatedSendingIcon()
                  else
                    const FaIcon(FontAwesomeIcons.paperPlane, size: 18, color: CupertinoColors.white),
                  const SizedBox(width: 10),
                  Text(
                    _sending ? 'Sending…' : 'Send',
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
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/background.jpg',
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