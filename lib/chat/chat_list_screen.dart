import 'package:flutter/material.dart';
import 'chat_api.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Future<List<dynamic>> chats;

  @override
  void initState() {
    super.initState();
    chats = ChatApi.getChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: FutureBuilder(
        future: chats,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return const Center(child: Text('Error'));
          }

          final data = s.data as List;

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (_, i) {
              final chat = data[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(chat['name'] ?? 'User'),
                subtitle: Text(chat['lastMessage'] ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(chatId: chat['id']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
