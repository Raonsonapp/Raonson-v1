import 'package:flutter/material.dart';
import 'reel_api.dart';
import 'reel_model.dart';
import '../comments/comments_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<Reel>> future;

  @override
  void initState() {
    super.initState();
    future = ReelApi.getReels();
  }

  Future<void> refresh() async {
    setState(() {
      future = ReelApi.getReels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Reel>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reels = snap.data!;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (context, i) {
              final r = reels[i];

              // add view once shown
              ReelApi.addView(r.id);

              return Stack(
                children: [
                  // VIDEO PLACEHOLDER (баъд video_player мепайвандем)
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.play_circle,
                          size: 80, color: Colors.white54),
                    ),
                  ),

                  // RIGHT ACTIONS
                  Positioned(
                    right: 12,
                    bottom: 120,
                    child: Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            r.liked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: r.liked ? Colors.red : Colors.white,
                            size: 28,
                          ),
                          onPressed: () async {
                            await ReelApi.toggleLike(r.id);
                            refresh();
                          },
                        ),
                        Text('${r.likes}',
                            style:
                                const TextStyle(color: Colors.white)),

                        const SizedBox(height: 12),

                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommentsScreen(postId: r.id),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        IconButton(
                          icon: Icon(
                            r.saved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            await ReelApi.toggleSave(r.id);
                            refresh();
                          },
                        ),
                      ],
                    ),
                  ),

                  // BOTTOM INFO
                  Positioned(
                    left: 12,
                    bottom: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${r.username}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Reel caption',
                            style:
                                TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
