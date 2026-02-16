import 'package:flutter/material.dart';
import 'chat_api.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List chats = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    chats = await ChatApi.getChats();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Messages'),
      ),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (_, i) {
          final chat = chats[i];
          final user = chat['members'][1];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['avatar']),
            ),
            title: Text(user['username'],
                style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: chat['_id']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
