import 'package:flutter/material.dart';
import 'chat_api.dart';

class ChatScreen extends StatefulWidget {
  final Map chat;
  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctrl = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    ChatApi.markSeen(widget.chat['_id']);
  }

  Future<void> send() async {
    if (ctrl.text.isEmpty || sending) return;
    sending = true;

    await ChatApi.sendMessage(
      chatId: widget.chat['_id'],
      text: ctrl.text.trim(),
    );

    ctrl.clear();
    sending = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'Messages render here (realtime next step)',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Message…',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
