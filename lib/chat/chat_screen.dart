import 'package:flutter/material.dart';
import 'chat_api.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<List<dynamic>> messages;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    messages = ChatApi.getMessages(widget.chatId);
  }

  void send() async {
    if (ctrl.text.isEmpty) return;
    await ChatApi.sendMessage(widget.chatId, ctrl.text);
    ctrl.clear();
    setState(() {
      messages = ChatApi.getMessages(widget.chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder(
              future: messages,
              builder: (c, s) {
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = s.data as List;
                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (_, i) {
                    final m = data[i];
                    return Align(
                      alignment: m['me'] == true
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m['me'] == true
                              ? Colors.blue
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          m['text'],
                          style: TextStyle(
                              color: m['me'] == true
                                  ? Colors.white
                                  : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration:
                      const InputDecoration(hintText: 'Message...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: send,
              )
            ],
          )
        ],
      ),
    );
  }
}
