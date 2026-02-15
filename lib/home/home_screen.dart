import 'package:flutter/material.dart';

// STORIES
import '../stories/stories_bar.dart';

// UPLOAD
import '../upload/upload_modal.dart';

// POSTS
import 'post_item.dart';
import 'post_model.dart';
import 'home_api.dart';

// NOTIFICATIONS
import '../notifications/notifications_screen.dart';

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
    } catch (_) {
      loading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,

        // ➕ UPLOAD (NO BORDER)
        leading: IconButton(
          icon: const Icon(Icons.add, size: 28),
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.black,
              isScrollControlled: true,
              builder: (_) => const UploadModal(),
            );
            loadFeed(); // 🔄 refresh after upload
          },
        ),

        // 🧠 LOGO
        title: const Text(
          'Raonson',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: true,

        // ❤️ NOTIFICATIONS
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),

      // ================= BODY =================
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RefreshIndicator(
              onRefresh: loadFeed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // ================= STORIES =================
                  const StoriesBar(),

                  const Divider(color: Colors.white12),

                  // ================= FEED =================
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
