import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/token_storage.dart';
import '../comments/comments_screen.dart';

// ================== MODELS ==================

class Story {
  final String id;
  final String username;

  Story({required this.id, required this.username});

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['_id'] ?? '',
      username: json['username'] ?? 'user',
    );
  }
}

class Post {
  final String id;
  final String username;
  final String caption;
  final int likes;
  final bool liked;
  final bool saved;

  Post({
    required this.id,
    required this.username,
    required this.caption,
    required this.likes,
    required this.liked,
    required this.saved,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? '',
      username: json['username'] ?? 'user',
      caption: json['caption'] ?? '',
      likes: json['likesCount'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
    );
  }
}

// ================== SCREEN ==================

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<Post>> feedFuture;
  late Future<List<Story>> storyFuture;

  @override
  void initState() {
    super.initState();
    feedFuture = fetchFeed();
    storyFuture = fetchStories();
  }

  Future<void> refresh() async {
    setState(() {
      feedFuture = fetchFeed();
      storyFuture = fetchStories();
    });
  }

  // ================== API ==================

  Future<List<Post>> fetchFeed() async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/posts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Post.fromJson(e)).toList();
  }

  Future<List<Story>> fetchStories() async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/stories'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Story.fromJson(e)).toList();
  }

  Future<void> toggleLike(String postId) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/likes/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    refresh();
  }

  Future<void> toggleSave(String postId) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/save/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    refresh();
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Raonson',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          children: [
            // -------- STORIES --------
            FutureBuilder<List<Story>>(
              future: storyFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 90,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final stories = snap.data!;
                if (stories.isEmpty) {
                  return const SizedBox(height: 90);
                }

                return SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: stories.length,
                    itemBuilder: (context, i) {
                      final s = stories[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.username,
                              style:
                                  const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const Divider(color: Colors.grey),

            // -------- FEED --------
            FutureBuilder<List<Post>>(
              future: feedFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                        child: CircularProgressIndicator()),
                  );
                }

                final posts = snap.data!;
                if (posts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'No posts yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: posts.map((p) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person,
                                color: Colors.white),
                          ),
                          title: Text(
                            p.username,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          trailing:
                              const Icon(Icons.more_vert),
                        ),

                        // MEDIA
                        Container(
                          height: 280,
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(Icons.image,
                                size: 80,
                                color: Colors.grey),
                          ),
                        ),

                        // ACTIONS
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                p.liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: p.liked
                                    ? Colors.red
                                    : Colors.white,
                              ),
                              onPressed: () =>
                                  toggleLike(p.id),
                            ),
                            Text('${p.likes}'),

                            const SizedBox(width: 16),

                            IconButton(
                              icon: const Icon(
                                  Icons.chat_bubble_outline),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CommentsScreen(
                                            postId: p.id),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(width: 16),

                            IconButton(
                              icon: Icon(
                                p.saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              onPressed: () =>
                                  toggleSave(p.id),
                            ),
                          ],
                        ),

                        // CAPTION
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: p.username,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                                const TextSpan(text: '  '),
                                TextSpan(text: p.caption),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
