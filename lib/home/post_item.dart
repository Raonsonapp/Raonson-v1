import 'package:flutter/material.dart';
import 'post_model.dart';
import 'home_api.dart';
import '../comments/comments_screen.dart';

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
      widget.post.liked = true;
      widget.post.likes += 1;
      liking = true;
    });

    try {
      await HomeApi.likePost(widget.post.id);
    } catch (_) {
      // rollback агар backend хато диҳад
      setState(() {
        widget.post.liked = false;
        widget.post.likes -= 1;
      });
    } finally {
      liking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.post.media.isNotEmpty
        ? widget.post.media.first
        : null;

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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // ================= MEDIA =================
        if (media != null)
          media['type'] == 'image'
              ? Image.network(
                  media['url'],
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.play_circle,
                          color: Colors.white, size: 64),
                    ),
                  ),
                ),

        // ================= ACTIONS =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  widget.post.liked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color:
                      widget.post.liked ? Colors.red : Colors.white,
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
              const Icon(Icons.send, color: Colors.white),
              const Spacer(),
              const Icon(Icons.bookmark_border,
                  color: Colors.white),
            ],
          ),
        ),

        // ================= LIKES =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${widget.post.likes} likes',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ================= CAPTION =================
        if (widget.post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: widget.post.user,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(text: widget.post.caption),
                ],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

        const SizedBox(height: 12),
      ],
    );
  }
}
