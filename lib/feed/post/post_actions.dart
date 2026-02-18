import 'package:flutter/material.dart';
import '../../models/post_model.dart';

class PostActions extends StatelessWidget {
  final PostModel post;

  const PostActions({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).iconTheme.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked ? Colors.red : iconColor,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  post.saved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
                onPressed: () {},
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${post.likesCount} likes',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
