import 'package:flutter/material.dart';
import 'chat_api.dart';
import 'chat_model.dart';
import 'message_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  const ChatRoomScreen({super.key, required this.chatId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late Future<List<Message>> future;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = ChatApi.getMessages(widget.chatId);
  }

  Future<void> refresh() async {
    setState(() {
      future = ChatApi.getMessages(widget.chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                return ListView.builder(
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    return ListTile(
                      title: Text(m.text),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration:
                        const InputDecoration(hintText: 'Message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    await ChatApi.sendMessage(
                        widget.chatId, ctrl.text.trim());
                    ctrl.clear();
                    refresh();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
