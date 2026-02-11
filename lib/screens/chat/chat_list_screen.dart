import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/chat_tile.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Messages"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(
          children: [
            ChatTile(
              name: "raonson_user",
              lastMessage: "Hello from Raonson 👋",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatRoomScreen(),
                  ),
                );
              },
            ),
            ChatTile(
              name: "studio_dev",
              lastMessage: "UI looks clean 🔥",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatRoomScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
