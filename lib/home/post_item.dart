import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../comments/comments_screen.dart';
import 'post_model.dart';
import 'home_api.dart';

class PostItem extends StatefulWidget {
  final Post post;
  const PostItem({super.key, required this.post});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  bool liking = false;

  Future<void> onLike() async {
    if (liking) return;
    liking = true;

    setState(() {
      widget.post.liked = !widget.post.liked;
      widget.post.likes += widget.post.liked ? 1 : -1;
    });

    try {
      await HomeApi.likePost(widget.post.id);
    } catch (_) {
      // агар backend хато диҳад, UI мешиканад ❌ не
    }

    liking = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ================= HEADER =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, size: 18, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.user,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // ================= MEDIA (IMAGE / VIDEO) =================
        SizedBox(
          height: 360,
          child: PageView.builder(
            itemCount: widget.post.media.length,
            itemBuilder: (_, i) {
              final m = widget.post.media[i];
              if (m.type == 'video') {
                return _Video(url: m.url);
              }
              return Image.network(
                m.url,
                fit: BoxFit.cover,
                width: double.infinity,
              );
            },
          ),
        ),

        // ================= ACTIONS =================
        Row(
          children: [
            IconButton(
              icon: Icon(
                widget.post.liked
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: widget.post.liked ? Colors.red : Colors.white,
              ),
              onPressed: onLike,
            ),
            IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CommentsScreen(postId: widget.post.id),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),

        // ================= LIKES =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            widget.post.likes > 0
                ? '${widget.post.likes} likes'
                : 'Be the first to like this',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ================= CAPTION =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.post.user,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: widget.post.caption,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ================= VIDEO PLAYER =================

class _Video extends StatefulWidget {
  final String url;
  const _Video({required this.url});

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return VideoPlayer(controller);
  }
}
