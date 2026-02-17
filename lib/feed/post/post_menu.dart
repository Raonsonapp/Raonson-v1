import 'package:flutter/material.dart';

import '../../models/post_model.dart';

class PostMenu extends StatelessWidget {
  final PostModel post;

  const PostMenu({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'report':
            // report post
            break;
          case 'block':
            // block user
            break;
          case 'delete':
            // delete post
            break;
          case 'copy':
            // copy link
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'copy',
          child: Text('Copy link'),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Text('Report'),
        ),
        const PopupMenuItem(
          value: 'block',
          child: Text('Block user'),
        ),
        if (post.isOwner)
          const PopupMenuItem(
            value: 'delete',
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
