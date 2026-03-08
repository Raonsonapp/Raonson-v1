import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/storage/token_storage.dart';
import '../../core/webrtc_service.dart';
import '../../core/presence_service.dart';
import 'message_bubble.dart';
import 'message_input.dart';
import 'call_screen.dart';
import 'incoming_call_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final UserModel peer;
  const ChatRoomScreen({super.key, required this.peer});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _repo     = ChatRepository();
  final _scroll   = ScrollController();
  final _signal   = WebRTCService();
  final _presence = PresenceService();

  List<MessageModel> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _setup();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _signal.onIncomingCall = null;
    _presence.removeListener(_onPresence);
    super.dispose();
  }

  void _onPresence() {
    if (mounted) setState(() {});
  }

  Future<void> _setup() async {
    await _signal.connect();
    await _presence.connect();

    _presence.addListener(_onPresence);
    _presence.checkUser(widget.peer.id);

    _signal.onIncomingCall = (from, fromUsername, fromAvatar, callType) {
      if (!mounted) return;
      final ct = callType == 'video' ? CallType.video : CallType.voice;
      final caller = UserModel(
        id: from,
        username: fromUsername.isNotEmpty ? fromUsername : widget.peer.username,
        avatar:   fromAvatar.isNotEmpty   ? fromAvatar   : widget.peer.avatar,
        verified: false, isPrivate: false,
        postsCount: 0, followersCount: 0, followingCount: 0,
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => IncomingCallScreen(caller: caller, callType: ct),
      ));
    };
  }

  Future<void> _load() async {
    try {
      final msgs = await _repo.getMessagesWithUser(widget.peer.id);
      setState(() { _messages = msgs; _loading = false; });
      _scrollBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSend(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final msg = await _repo.sendMessage(toUserId: widget.peer.id, text: text);
      setState(() => _messages.add(msg));
      _scrollBottom();
    } catch (_) {}
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startCall(CallType type) async {
    final myId   = await TokenStorage.getUserId() ?? '';
    final myData = await _repo.getMyProfile();

    _signal.notifyIncoming(
      toUserId:     widget.peer.id,
      fromUserId:   myId,
      fromUsername: myData?['username'] ?? '',
      fromAvatar:   myData?['avatar']   ?? '',
      isVideo:      type == CallType.video,
    );

    if (!mounted) return;
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => CallScreen(
        peer:         widget.peer,
        callType:     type,
        peerIsOnline: _presence.isOnline(widget.peer.id),
      ),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  bool   get _online => _presence.isOnline(widget.peer.id);
  String get _label  => _presence.lastSeenLabel(widget.peer.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          // Avatar with online dot
          Stack(clipBehavior: Clip.none, children: [
            Avatar(imageUrl: widget.peer.avatar, size: 38, glowBorder: false),
            if (_online)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.peer.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              // Presence label
              Text(
                _label.isNotEmpty ? _label : 'профилро бинед',
                style: TextStyle(
                  color: _online
                      ? const Color(0xFF00E676)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: _online ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ]),
        actions: [
          _AppBarBtn(icon: Icons.videocam_rounded, onTap: () => _startCall(CallType.video)),
          _AppBarBtn(icon: Icons.call_rounded,     onTap: () => _startCall(CallType.voice)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonBlue))
                : _messages.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => MessageBubble(message: _messages[i]),
                      ),
          ),
          MessageInput(onSend: _onSend),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            Avatar(imageUrl: widget.peer.avatar, size: 80, glowBorder: true),
            if (_online)
              Positioned(
                bottom: 3, right: 3,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 3),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Text(widget.peer.username,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            _label.isNotEmpty ? _label : '',
            style: TextStyle(
              color: _online ? const Color(0xFF00E676) : Colors.white38,
              fontSize: 13,
              fontWeight: _online ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Чизе гӯед! 👋',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickBtn(icon: Icons.call_rounded, label: 'Зангӣ овозӣ',
                  onTap: () => _startCall(CallType.voice)),
              const SizedBox(width: 16),
              _QuickBtn(icon: Icons.videocam_rounded, label: 'Зангӣ видео',
                  onTap: () => _startCall(CallType.video)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
    onPressed: onTap,
  );
}

class _QuickBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.neonBlue, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    ),
  );
}
