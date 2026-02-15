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
  Future<void> onLike() async {
    setState(() {
      widget.post.liked = true;
      widget.post.likes += 1;
    });

    final likes = await HomeApi.like(widget.post.id);
    setState(() => widget.post.likes = likes);
  }

  Future<void> onSave() async {
    final saved = await HomeApi.toggleSave(widget.post.id);
    setState(() => widget.post.saved = saved);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.orange),
              const SizedBox(width: 8),
              Text(widget.post.user,
                  style: const TextStyle(color: Colors.white)),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // MEDIA
        SizedBox(
          height: 380,
          child: PageView(
            children: widget.post.media
                .map((url) => Image.network(url, fit: BoxFit.cover))
                .toList(),
          ),
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
            IconButton(
              icon:
                  const Icon(Icons.mode_comment_outlined, color: Colors.white),
              onPressed: () {},
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
              onPressed: onSave,
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${widget.post.likes} likes',
            style: const TextStyle(color: Colors.white),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
