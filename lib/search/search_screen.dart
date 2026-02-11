import 'package:flutter/material.dart';
import 'search_api.dart';
import 'search_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctrl = TextEditingController();
  List<SearchUser> users = [];
  List<SearchPost> posts = [];
  bool loading = false;

  Future<void> runSearch(String q) async {
    if (q.isEmpty) return;
    setState(() => loading = true);
    final res = await SearchApi.search(q);
    setState(() {
      users = res['users'];
      posts = res['posts'];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Search',
            border: InputBorder.none,
          ),
          onSubmitted: runSearch,
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (users.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Users',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ...users.map((u) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(u.username),
                      onTap: () {
                        // open ProfileScreen(userId: u.id)
                      },
                    )),

                if (posts.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Posts',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ...posts.map((p) => ListTile(
                      leading: const Icon(Icons.image),
                      title: Text(p.caption),
                    )),
              ],
            ),
    );
  }
}
