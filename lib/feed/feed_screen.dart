import 'package:flutter/material.dart';
import 'feed_api.dart';
import 'feed_model.dart';

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
    future = FeedApi.getPosts();
  }

  Future<void> refresh() async {
    setState(() {
      future = FeedApi.getPosts();
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
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No posts yet',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final posts = snapshot.data!;

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE
                    Image.network(post.image),

                    // ACTIONS
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () async {
                            await FeedApi.likePost(post.id);
                            refresh();
                          },
                        ),
                        Text(
                          '${post.likes}',
                          style:
                              const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon:
                              const Icon(Icons.bookmark_border),
                          onPressed: () async {
                            await FeedApi.savePost(post.id);
                            refresh();
                          },
                        ),
                        Text(
                          '${post.saved}',
                          style:
                              const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    // CAPTION
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        post.caption,
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
