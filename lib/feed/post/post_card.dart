import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/media_viewer.dart';
import 'post_actions.dart';
import 'post_menu.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ================= HEADER =================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Avatar(
                imageUrl: post.user.avatar,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      post.user.username,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (post.user.verified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 14),
                    ],
                  ],
                ),
              ),
              PostMenu(post: post),
            ],
          ),
        ),

        // ================= MEDIA =================
        MediaViewer(
          mediaUrls: post.media,
        ),

        // ================= ACTIONS =================
        PostActions(post: post),

        // ================= CAPTION =================
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: post.user.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),
      ],
    );
  }
}
