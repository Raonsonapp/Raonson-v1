import 'package:flutter/material.dart';

import '../../models/comment_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';

class CommentItem extends StatelessWidget {
  final CommentModel comment;

  const CommentItem({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            imageUrl: comment.user.avatar,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.user.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (comment.user.verified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.text),
                const SizedBox(height: 4),
                Text(
                  comment.timeAgo,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(
            comment.isLiked
                ? Icons.favorite
                : Icons.favorite_border,
            size: 18,
            color: comment.isLiked ? Colors.red : null,
          ),
        ],
      ),
    );
  }
}
