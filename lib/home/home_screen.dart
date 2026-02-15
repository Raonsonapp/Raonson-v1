import 'package:flutter/material.dart';
import '../upload/upload_modal.dart';
import 'post_item.dart';
import 'post_model.dart';
import 'home_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  List<Post> posts = [];

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  Future<void> loadFeed() async {
    try {
      final data = await HomeApi.fetchFeed();
      setState(() {
        posts = data.map<Post>((e) => Post.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      loading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // 🔝 APP BAR (Instagram-style)
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,

        // ➕ UPLOAD (бе рамка)
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.black,
              builder: (_) => const UploadModal(),
            ).then((_) => loadFeed()); // 🔄 refresh after upload
          },
        ),

        // 🧠 LOGO / TITLE
        title: const Text(
          'Raonson',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,

        // ❤️ NOTIFICATIONS
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // баъд NotificationsScreen
            },
          ),
        ],
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RefreshIndicator(
              onRefresh: loadFeed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // 📸 STORIES (ҳоло static, баъд зинда)
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      children: const [
                        _StoryItem(isMe: true, username: 'Your story'),
                        _StoryItem(username: 'raonson'),
                        _StoryItem(username: 'user_1'),
                        _StoryItem(username: 'user_2'),
                        _StoryItem(username: 'user_3'),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12),

                  // 📰 POSTS
                  if (posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No posts yet',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    ...posts.map((p) => PostItem(post: p)),
                ],
              ),
            ),
    );
  }
}

// ================= STORIES =================

class _StoryItem extends StatelessWidget {
  final String username;
  final bool isMe;

  const _StoryItem({
    this.username = '',
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange,
            child: CircleAvatar(
              radius: 27,
              backgroundColor: Colors.black,
              child: isMe
                  ? const Icon(Icons.add, color: Colors.orange)
                  : const Icon(Icons.person, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
