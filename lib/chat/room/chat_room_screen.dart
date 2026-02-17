import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import 'message_bubble.dart';
import 'message_input.dart';

class ChatRoomScreen extends StatefulWidget {
  final UserModel peer;

  const ChatRoomScreen({
    super.key,
    required this.peer,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final repo = context.read<ChatRepository>();
    final data = await repo.getMessagesWithUser(widget.peer.id);
    setState(() {
      _messages = data;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _onSend(String text) async {
    if (text.trim().isEmpty) return;

    final repo = context.read<ChatRepository>();
    final msg = await repo.sendMessage(
      toUserId: widget.peer.id,
      text: text,
    );

    setState(() {
      _messages.add(msg);
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peer.username),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return MessageBubble(message: msg);
                    },
                  ),
          ),
          MessageInput(onSend: _onSend),
        ],
      ),
    );
  }
}
