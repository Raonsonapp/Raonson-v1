import 'package:flutter/material.dart';
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
      liking = true;
      widget.post.liked = true;
      widget.post.likes += 1;
    });

    try {
      final newLikes = await HomeApi.likePost(widget.post.id);
      setState(() => widget.post.likes = newLikes);
    } catch (_) {}

    liking = false;
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.post.media.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.user,
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // MEDIA
        Image.network(
          media.url,
          fit: BoxFit.cover,
          width: double.infinity,
        ),

        // ACTIONS
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
            const Icon(Icons.chat_bubble_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Icon(Icons.send, color: Colors.white),
            const Spacer(),
            const Icon(Icons.bookmark_border, color: Colors.white),
          ],
        ),

        // LIKES
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            widget.post.likes == 0
                ? 'Be the first to like this'
                : 'Liked by ${widget.post.user}',
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // CAPTION
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            widget.post.caption,
            style: const TextStyle(color: Colors.white),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
