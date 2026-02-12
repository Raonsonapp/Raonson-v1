import 'package:flutter/material.dart';
import 'feed_api.dart';
import 'feed_model.dart';
import '../comments/comments_screen.dart';
import '../profile/profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<FeedPost>> future;

  @override
  void initState() {
    super.initState();
    future = FeedApi.getFeed();
  }

  Future<void> refresh() async {
    setState(() {
      future = FeedApi.getFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Raonson'),
        backgroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<FeedPost>>(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final posts = snap.data!;
            if (posts.isEmpty) {
              return const Center(
                child: Text(
                  'No posts yet',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final p = posts[i];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- HEADER ----------
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(userId: p.userId),
                            ),
                          );
                        },
                        child: Text(
                          p.userId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      trailing: const Icon(Icons.more_vert),
                    ),

                    // ---------- IMAGE ----------
                    Image.network(
                      p.image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),

                    // ---------- ACTIONS ----------
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () async {
                            await FeedApi.like(p.id);
                            refresh();
                          },
                        ),
                        Text(
                          p.likes.toString(),
                          style:
                              const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommentsScreen(postId: p.id),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.bookmark_border),
                          onPressed: () async {
                            await FeedApi.save(p.id);
                            refresh();
                          },
                        ),
                        Text(
                          p.saved.toString(),
                          style:
                              const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    // ---------- CAPTION ----------
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        p.caption,
                        style:
                            const TextStyle(color: Colors.white),
                      ),
                    ),

                    const Divider(color: Colors.grey),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
