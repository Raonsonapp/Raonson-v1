import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [
    {"text": "Hello 👋", "me": false},
    {"text": "Welcome to Raonson!", "me": true},
  ];

  void sendMessage() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      messages.add({"text": controller.text, "me": true});
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("@raonson_user"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                return MessageBubble(
                  text: m["text"],
                  isMe: m["me"],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: RColors.card,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: RColors.white),
                    decoration: const InputDecoration(
                      hintText: "Message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: RColors.neon),
                  onPressed: sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
