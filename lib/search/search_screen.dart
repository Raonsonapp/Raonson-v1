import 'package:flutter/material.dart';
import 'search_api.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctrl = TextEditingController();
  Map<String, dynamic>? result;
  bool loading = false;

  void doSearch() async {
    if (ctrl.text.isEmpty) return;
    setState(() => loading = true);
    result = await SearchApi.search(ctrl.text);
    setState(() => loading = false);
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
          onSubmitted: (_) => doSearch(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : result == null
              ? const Center(child: Text('Search users or posts'))
              : ListView(
                  children: [
                    if ((result!['users'] as List).isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Users',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ...(result!['users'] as List).map((u) => ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.person)),
                            title: Text(u['username']),
                          )),
                    ],
                    if ((result!['posts'] as List).isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Posts',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ...(result!['posts'] as List).map((p) => Image.network(
                            p['image'],
                            height: 220,
                            fit: BoxFit.cover,
                          )),
                    ]
                  ],
                ),
    );
  }
}
