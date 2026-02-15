import 'package:flutter/material.dart';
import 'post_model.dart';
import '../comments/comments_screen.dart';
import 'home_api.dart';

class PostItem extends StatefulWidget {
  final Post post;
  const PostItem({super.key, required this.post});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  late int likes;
  late bool liked;

  @override
  void initState() {
    super.initState();
    likes = widget.post.likes;
    liked = widget.post.liked;
  }

  Future<void> onLike() async {
    if (liked) return;

    setState(() {
      liked = true;
      likes += 1;
    });

    try {
      await HomeApi.likePost(widget.post.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔝 HEADER
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
                widget.post.username,
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // 🖼 IMAGE
        Image.network(
          widget.post.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
        ),

        // ❤️ 💬 ✈️ 🔖 ACTIONS
        Row(
          children: [
            IconButton(
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                color: liked ? Colors.red : Colors.white,
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
              icon: const Icon(Icons.bookmark_border,
                  color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),

        // ❤️ LIKES TEXT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            liked
                ? 'Liked by ${widget.post.username}'
                : 'Be the first to like this',
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // 📝 CAPTION
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
