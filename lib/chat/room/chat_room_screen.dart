import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/storage/token_storage.dart';
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
  final _repo   = ChatRepository();
  final _scroll = ScrollController();
  List<MessageModel> _messages = [];
  bool _loading = true;

  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  // ── Connect socket and listen for incoming calls ──
  Future<void> _connectSocket() async {
    final myId = await TokenStorage.getUserId() ?? '';
    if (myId.isEmpty) return;

    _socket = io.io(
      'https://raonson-v1.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) => _socket!.emit('user:register', myId));

    _socket!.on('call:incoming', (data) {
      if (!mounted) return;
      final callType = data['callType'] == 'video' ? CallType.video : CallType.voice;

      final caller = UserModel(
        id:             data['from'] ?? widget.peer.id,
        username:       data['fromUsername'] ?? widget.peer.username,
        avatar:         data['fromAvatar'] ?? widget.peer.avatar,
        verified:       false,
        isPrivate:      false,
        postsCount:     0,
        followersCount: 0,
        followingCount: 0,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            caller:    caller,
            offerData: Map<String, dynamic>.from(data['offer'] ?? {}),
            callType:  callType,
          ),
        ),
      );
    });
  }

  Future<void> _load() async {
    try {
      final msgs = await _repo.getMessagesWithUser(widget.peer.id);
      setState(() {
        _messages = msgs;
        _loading  = false;
      });
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

  void _startVoiceCall() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => CallScreen(peer: widget.peer, callType: CallType.voice),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );

  void _startVideoCall() => Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => CallScreen(peer: widget.peer, callType: CallType.video),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );

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
        title: Row(
          children: [
            Avatar(imageUrl: widget.peer.avatar, size: 36, glowBorder: true),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peer.username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('tap to view profile',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
            ),
            onPressed: _startVideoCall,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
            ),
            onPressed: _startVoiceCall,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.neonBlue))
                : _messages.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Avatar(imageUrl: widget.peer.avatar, size: 80, glowBorder: true),
          const SizedBox(height: 16),
          Text(widget.peer.username,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Say something! 👋', style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickBtn(icon: Icons.call_rounded, label: 'Voice call', onTap: _startVoiceCall),
              const SizedBox(width: 16),
              _QuickBtn(icon: Icons.videocam_rounded, label: 'Video call', onTap: _startVideoCall),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.neonBlue, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
