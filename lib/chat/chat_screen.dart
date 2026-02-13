import 'package:flutter/material.dart';
import 'chat_api.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<List<dynamic>> future;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = ChatApi.getMessages(widget.chatId);
  }

  void refresh() {
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
            child: FutureBuilder(
              future: future,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final messages = snap.data!;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Align(
                        alignment: messages[i]['mine']
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: messages[i]['mine']
                                ? Colors.blue
                                : Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            messages[i]['text'],
                            style: TextStyle(
                              color: messages[i]['mine']
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
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
                  controller: controller,
                  decoration:
                      const InputDecoration(hintText: 'Message'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  await ChatApi.sendMessage(
                      widget.chatId, controller.text);
                  controller.clear();
                  refresh();
                },
              )
            ],
          )
        ],
      ),
    );
  }
}
