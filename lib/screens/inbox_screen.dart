import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/mail_message.dart';
import '../api/mail_repository.dart';
import '../widgets/mail_tile.dart';
import 'compose_screen.dart';
import 'message_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.repository});

  final MailRepository? repository;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final MailRepository _repo;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _deletedMsgIds = <int>{};
  Timer? _autoRefreshTimer;

  List<MailMessage> _messages = const <MailMessage>[];
  bool _loading = true;
  String? _error;
  int _selectedTabIndex = 0;

  static final MailMessage _placeholder = MailMessage(
    id: -1,
    fromEmail: 'loading@placeholder.example',
    fromName: 'Loading sender',
    subject: 'Loading subject line',
    preview: 'Loading a longer message preview line that wraps nicely on screen.',
    body: '',
    date: DateTime.now(),
    seen: false,
  );

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RemoteMailRepository(ApiClient());
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await _repo.listMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages.where((m) => !_deletedMsgIds.contains(m.id)).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('Something went wrong while loading your inbox.');
    }
  }

  Future<void> _refresh() async {
    try {
      final messages = await _repo.listMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages.where((m) => !_deletedMsgIds.contains(m.id)).toList();
        _error = null;
      });
    } catch (_) {
    }
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _loading) return;
    try {
      final messages = await _repo.listMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages.where((m) => !_deletedMsgIds.contains(m.id)).toList();
        _error = null;
      });
    } catch (_) {
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  Future<void> _openCompose() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => ComposeScreen(repository: _repo),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
      ),
    );
    _refresh();
  }

  Future<void> _openMessage(MailMessage message) async {
    final deleted = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => MessageDetailScreen(
          messageId: message.id,
          repository: _repo,
        ),
      ),
    );
    if (deleted == true) {
      _deletedMsgIds.add(message.id);
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m.id != message.id).toList();
      });
    } else {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: _buildBackground(),
      appBar: GlassAppBar(
        title: Text(
          _titleForTab(_selectedTabIndex),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: CupertinoColors.white,
          ),
        ),
      ),
      bottomBar: GlassTabBar.bottom(
        selectedIndex: _selectedTabIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        extraButton: GlassTabBarExtraButton(
          icon: const FaIcon(
            FontAwesomeIcons.penToSquare,
            key: ValueKey('compose-open'),
            size: 18,
            color: CupertinoColors.white,
          ),
          label: 'Compose',
          onTap: _openCompose,
        ),
        settings: const LiquidGlassSettings(
          chromaticAberration: 0.08,
        ),
        tabs: [
          GlassTab(
            icon: FaIcon(
              FontAwesomeIcons.inbox,
              size: 20,
              color: _selectedTabIndex == 0
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
          GlassTab(
            icon: FaIcon(
              FontAwesomeIcons.bell,
              size: 20,
              color: _selectedTabIndex == 1
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
          GlassTab(
            icon: FaIcon(
              FontAwesomeIcons.user,
              size: 20,
              color: _selectedTabIndex == 2
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildTabBody(_selectedTabIndex),
      ),
    );
  }

  String _titleForTab(int index) {
    switch (index) {
      case 1:
        return 'Notifications';
      case 2:
        return 'Profile';
      case 0:
      default:
        return 'Inbox';
    }
  }

  Widget _buildTabBody(int index) {
    switch (index) {
      case 1:
        return _buildNotificationsView();
      case 2:
        return _buildProfileView();
      case 0:
      default:
        return _buildBody();
    }
  }

  Widget _buildNotificationsView() {
    if (_loading) {
      return Skeletonizer(
        enabled: true,
        enableSwitchAnimation: true,
        switchAnimationConfig: const SwitchAnimationConfig(
          duration: Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
        ),
        effect: const ShimmerEffect(
          baseColor: Color(0x22FFFFFF),
          highlightColor: Color(0x66FFFFFF),
          duration: Duration(milliseconds: 1200),
        ),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            16 + MediaQuery.paddingOf(context).top + 56,
            16,
            110,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildNotificationTile(
              icon: const FaIcon(FontAwesomeIcons.envelope, size: 16, color: CupertinoColors.activeBlue),
              bgColor: CupertinoColors.activeBlue.withValues(alpha: 0.18),
              title: 'Loading notification title',
              subtitle: 'Loading notification subtitle preview details...',
              time: '1m ago',
            ),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.bellSlash, size: 42, color: CupertinoColors.systemGrey),
              SizedBox(height: 16),
              Text(
                'No notifications',
                style: TextStyle(color: CupertinoColors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'You are all caught up!',
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.paddingOf(context).top + 56,
        16,
        110,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final sender = msg.fromName.isNotEmpty ? msg.fromName : msg.fromEmail;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _openMessage(msg),
            child: _buildNotificationTile(
              icon: FaIcon(
                msg.unread ? FontAwesomeIcons.solidEnvelope : FontAwesomeIcons.envelopeOpen,
                size: 16,
                color: msg.unread ? CupertinoColors.activeBlue : CupertinoColors.systemGrey,
              ),
              bgColor: (msg.unread ? CupertinoColors.activeBlue : CupertinoColors.systemGrey).withValues(alpha: 0.18),
              title: msg.unread ? 'New message from $sender' : 'Message from $sender',
              subtitle: msg.subject,
              time: _relativeTime(msg.date),
            ),
          ),
        );
      },
    );
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final phtDate = date.toUtc().add(const Duration(hours: 8));
    final phtNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final diff = phtNow.difference(phtDate);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Widget _buildNotificationTile({
    required Widget icon,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      shape: const LiquidRoundedRectangle(borderRadius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: icon,
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
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: CupertinoColors.systemGrey2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        20 + MediaQuery.paddingOf(context).top + 56,
        16,
        110,
      ),
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          shape: const LiquidRoundedRectangle(borderRadius: 22),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: CupertinoColors.white.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: FaIcon(FontAwesomeIcons.userGroup, size: 30, color: CupertinoColors.white),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'CPE Elective Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Project Email Sending',
                    style: TextStyle(fontSize: 13,
                    color: CupertinoColors.white),

              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shape: const LiquidRoundedRectangle(borderRadius: 20),
          child: Column(
            children: [
              _buildProfileItem(
                icon: const FaIcon(FontAwesomeIcons.userGear, size: 16, color: Color(0xFF60A5FA)),
                title: 'Ferrer, Jhercy C',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: CupertinoColors.white.withValues(alpha: 0.1)),
              ),
              _buildProfileItem(
                icon: const FaIcon(FontAwesomeIcons.user, size: 16, color: Color(0xFF60A5FA)),
                title: 'Tedios Adrian',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: CupertinoColors.white.withValues(alpha: 0.1)),
              ),
              _buildProfileItem(
                icon: const FaIcon(FontAwesomeIcons.user, size: 16, color: Color(0xFF60A5FA)),
                title: 'Tambiga Novie',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: CupertinoColors.white.withValues(alpha: 0.1)),
              ),
              _buildProfileItem(
                icon: const FaIcon(FontAwesomeIcons.user, size: 16, color: Color(0xFF60A5FA)),
                title: 'Pereyra Angela',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: CupertinoColors.white.withValues(alpha: 0.1)),
              ),
              _buildProfileItem(
                icon: const FaIcon(FontAwesomeIcons.user, size: 16, color: Color(0xFF60A5FA)),
                title: 'Alvarez Aaron',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem({
    required Widget icon,
    required String title,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onPressed: () {},
      child: Row(
        children: [
          Container(
            width: 32,
            alignment: Alignment.centerLeft,
            child: icon,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 12,
            color: CupertinoColors.systemGrey,
          ),
        ],
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

  List<MailMessage> get _displayMessages {
    final Map<String, MailMessage> threads = {};
    for (final m in _messages) {
      if (_deletedMsgIds.contains(m.id)) continue;

      final cleanSubj = MailMessage.formatSubject(m.subject)
          .replaceAll('Reply:', '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      final emailKey = m.fromEmail.trim().toLowerCase();
      final myMailbox = ApiConfig.mailbox.toLowerCase();

      final key = (cleanSubj.isNotEmpty && cleanSubj != 'nosubject')
          ? 'subj:$cleanSubj'
          : (emailKey.isNotEmpty && emailKey != myMailbox ? 'email:$emailKey' : 'msg:${m.id}');

      if (!threads.containsKey(key)) {
        threads[key] = m;
      } else {
        final existing = threads[key]!;
        if (m.date != null && (existing.date == null || m.date!.isAfter(existing.date!))) {
          threads[key] = m;
        }
      }
    }
    return threads.values.toList();
  }

  Widget _buildBody() {
    final showSkeleton = _loading || _error != null;
    final displayList = _displayMessages;
    final itemCount = showSkeleton ? 8 : displayList.length;

    return Skeletonizer(
      enabled: showSkeleton,
      enableSwitchAnimation: true,
      switchAnimationConfig: const SwitchAnimationConfig(
        duration: Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
      ),
      effect: const ShimmerEffect(
        baseColor: Color(0x22FFFFFF),
        highlightColor: Color(0x66FFFFFF),
        duration: Duration(milliseconds: 1200),
      ),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(onRefresh: _refresh),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              16 + MediaQuery.paddingOf(context).top + 56,
              16,
              110,
            ),
            sliver: SliverList.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                final message = showSkeleton ? _placeholder : displayList[index];
                if (showSkeleton) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MailTile(message: message),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey('dismiss-${message.id}'),
                    direction: DismissDirection.startToEnd,
                    dismissThresholds: const {
                      DismissDirection.startToEnd: 0.25,
                    },
                    confirmDismiss: (direction) async {
                      final confirmed = await GlassDialog.show<bool>(
                        context: context,
                        title: 'Delete message?',
                        message: 'Are you sure you want to delete this message?',
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
                      return confirmed == true;
                    },
                    onDismissed: (direction) {
                      final msgId = message.id;
                      _deletedMsgIds.add(msgId);
                      setState(() {
                        _messages = _messages.where((m) => m.id != msgId).toList();
                      });
                      _repo.deleteMessage(msgId).catchError((_) {
                        _deletedMsgIds.remove(msgId);
                        if (mounted) _refresh();
                      });
                    },
                    background: Container(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.only(left: 20),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.trash,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: MailTile(
                      message: message,
                      onTap: () => _openMessage(message),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
