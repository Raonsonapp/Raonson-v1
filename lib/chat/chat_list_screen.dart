import 'package:flutter/material.dart';
import 'chat_api.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = ChatApi.getChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snap.data!;
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (_, i) {
              final c = chats[i];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(c['username']),
                subtitle: Text(c['lastMessage'] ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(chatId: c['id']),
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
