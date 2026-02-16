import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../home/post_item.dart';
import 'search_api.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctrl = TextEditingController();
  List users = [];
  List posts = [];
  bool loading = false;

  Future<void> onSearch(String q) async {
    if (q.isEmpty) {
      setState(() {
        users = [];
        posts = [];
      });
      return;
    }

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: onSearch,
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : ListView(
              children: [
                if (users.isNotEmpty) _Users(users),
                if (posts.isNotEmpty) _Posts(posts),
              ],
            ),
    );
  }
}

class _Users extends StatelessWidget {
  final List users;
  const _Users(this.users);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: users.map((u) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                u['avatar'] != null ? NetworkImage(u['avatar']) : null,
          ),
          title: Row(
            children: [
              Text(u['username'],
                  style: const TextStyle(color: Colors.white)),
              if (u['verified'] == true)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child:
                      Icon(Icons.verified, color: Colors.blue, size: 16),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: u['_id']),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _Posts extends StatelessWidget {
  final List posts;
  const _Posts(this.posts);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: posts.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemBuilder: (_, i) {
        final media = posts[i]['media'][0];
        return Image.network(media['url'], fit: BoxFit.cover);
      },
    );
  }
}
