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

    setState(() {
      widget.post.liked = !widget.post.liked;
      widget.post.likes += widget.post.liked ? 1 : -1;
    });

    liking = true;
    try {
      await HomeApi.likePost(widget.post.id);
    } catch (_) {}
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

        // ================= MEDIA =================
        SizedBox(
          height: 360,
          child: PageView.builder(
            itemCount: widget.post.media.length,
            itemBuilder: (_, i) {
              final m = widget.post.media[i];
              return m.type == 'video'
                  ? _VideoPost(url: m.url)
                  : Image.network(
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
              icon: const Icon(Icons.chat_bubble_outline,
                  color: Colors.white),
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
            const Spacer(),
            IconButton(
              icon: Icon(
                widget.post.saved
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => widget.post.saved = !widget.post.saved);
              },
            ),
          ],
        ),

        // ================= LIKES =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            widget.post.likes > 0
                ? 'Liked by ${widget.post.user}'
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

        const SizedBox(height: 12),
      ],
    );
  }
}

// ================= VIDEO POST =================

class _VideoPost extends StatefulWidget {
  final String url;
  const _VideoPost({required this.url});

  @override
  State<_VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<_VideoPost> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
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
