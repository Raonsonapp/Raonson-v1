import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
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
  List<MessageModel> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await _repo.getMessagesWithUser(widget.peer.id);
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSend(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final msg = await _repo.sendMessage(
        toUserId: widget.peer.id,
        text: text,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Avatar(imageUrl: widget.peer.avatar, size: 36, glowBorder: true),
            const SizedBox(width: 10),
            Text(
              widget.peer.username,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.neonBlue))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        MessageBubble(message: _messages[i]),
                  ),
          ),
          MessageInput(onSend: _onSend),
        ],
      ),
    );
  }
}
