import 'package:flutter/material.dart';
import 'profile_api.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map data = {};
  bool loading = true;
  bool following = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final res = await ProfileApi.fetch(widget.userId);
    setState(() {
      data = res;
      following = res['isFollowing'] ?? false;
      loading = false;
    });
  }

  Future<void> onFollow() async {
    final f = await ProfileApi.follow(widget.userId);
    setState(() => following = f);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final user = data['user'];
    final posts = data['posts'] as List;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Text(user['username'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (user['verified'] == true)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.verified, color: Colors.blue, size: 18),
              ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _Header(user, posts.length),
          const Divider(color: Colors.white12),
          Expanded(child: _PostsGrid(posts)),
        ],
      ),
    );
  }

  Widget _Header(Map user, int postsCount) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: user['avatar'] != null && user['avatar'] != ''
                    ? NetworkImage(user['avatar'])
                    : null,
                backgroundColor: Colors.grey.shade800,
              ),
              const Spacer(),
              _Stat(postsCount, 'Posts'),
              _Stat(user['followers'].length, 'Followers'),
              _Stat(user['following'].length, 'Following'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              user['bio'] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    following ? Colors.grey.shade800 : Colors.blue,
              ),
              child: Text(following ? 'Following' : 'Follow'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _Stat(int count, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text('$count',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  final List posts;
  const _PostsGrid(this.posts);

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts yet',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemBuilder: (_, i) {
        final media = posts[i]['media'][0];
        return Image.network(media['url'], fit: BoxFit.cover);
      },
    );
  }
}
