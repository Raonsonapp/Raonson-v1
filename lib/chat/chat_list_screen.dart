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
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await ChatApi.fetchChats();
    setState(() {
      chats = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Messages'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (_, i) {
                final c = chats[i];
                final last = c['lastMessage'];
                final seen = last?['seen'] == true;

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  title: Text(
                    c['users']
                        .firstWhere((u) => u['_id'] != 'me')['username'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    last?['text'] ?? '',
                    style: TextStyle(
                      color: seen ? Colors.white54 : Colors.white,
                      fontWeight:
                          seen ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  trailing: !seen
                      ? const Icon(Icons.circle,
                          color: Colors.blue, size: 10)
                      : null,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(chat: c),
                      ),
                    );
                    load();
                  },
                );
              },
            ),
    );
  }
}
