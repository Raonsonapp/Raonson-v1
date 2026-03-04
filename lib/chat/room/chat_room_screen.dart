import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import '../../core/services/user_session.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/services/socket_service.dart';
import 'message_bubble.dart';
import 'message_input.dart';

class ChatRoomScreen extends StatefulWidget {
  final UserModel peer;
  const ChatRoomScreen({super.key, required this.peer});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _repo = ChatRepository();
  final _scroll = ScrollController();
  final _socket = SocketService.instance;

  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _chatId;
  bool _peerTyping = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_chatId != null) _socket.leaveChat(_chatId!);
    _socket.offNewMessage();
    _socket.offTyping();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chatId = await _repo.getOrCreateChatId(widget.peer.id);
      final msgs = await _repo.getMessages(chatId);
      if (!mounted) return;
      setState(() {
        _chatId = chatId;
        _messages = msgs;
        _loading = false;
      });
      _setupSocket(chatId);
      _scrollBottom();
      _repo.markAsRead(chatId);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupSocket(String chatId) {
    _socket.joinChat(chatId);
    _socket.onNewMessage((data) {
      if (!mounted) return;
      final msg = MessageModel.fromRoomJson(data, UserSession.userId ?? '');
      setState(() => _messages.add(msg));
      _scrollBottom();
    });
    _socket.onTyping((_) {
      if (!mounted) return;
      setState(() => _peerTyping = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _peerTyping = false);
      });
    });
  }

  void _onSend(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      // Ensure chatId is loaded
      if (_chatId == null) {
        _chatId = await _repo.getOrCreateChatId(widget.peer.id);
      }
      final msg = await _repo.sendMessage(
        chatId: _chatId!,
        toUserId: widget.peer.id,
        text: text,
      );
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollBottom();
    } catch (e) {
      debugPrint('[Chat] send error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onTyping() {
    if (_chatId != null) {
      _socket.sendTyping(_chatId!, UserSession.userId ?? '');
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.neonBlue))
                : _messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length + (_peerTyping ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (_peerTyping && i == _messages.length) {
                            return _TypingBubble(username: widget.peer.username);
                          }
                          return MessageBubble(message: _messages[i]);
                        },
                      ),
          ),
          MessageInput(onSend: _onSend, onTyping: _onTyping),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Avatar(imageUrl: widget.peer.avatar, size: 36, glowBorder: true),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.peer.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  if (widget.peer.verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 14),
                  ],
                ],
              ),
              if (_peerTyping)
                const Text('typing...',
                    style: TextStyle(color: AppColors.neonBlue, fontSize: 11)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () {}),
        IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.white),
            onPressed: () {}),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(imageUrl: widget.peer.avatar, size: 72, glowBorder: true),
          const SizedBox(height: 12),
          Text(widget.peer.username,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Say something!',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final String username;
  const _TypingBubble({required this.username});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(delay: i * 200)),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _fade = Tween(begin: 0.2, end: 1.0).animate(_anim);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: 7, height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white54,
        ),
      ),
    );
  }
}
