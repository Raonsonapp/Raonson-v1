import 'package:flutter/material.dart';
import 'search_api.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctrl = TextEditingController();
  List users = [];
  bool loading = false;

  Future<void> search(String q) async {
    if (q.isEmpty) return;
    setState(() => loading = true);
    users = await SearchApi.users(q);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: search,
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(u['avatar'] ?? ''),
                  ),
                  title: Text(
                    u['username'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: u['verified'] == true
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : null,
                );
              },
            ),
    );
  }
}
