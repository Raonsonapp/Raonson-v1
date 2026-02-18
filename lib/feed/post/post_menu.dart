import 'package:flutter/material.dart';

import '../../models/post_model.dart';

class PostMenu extends StatelessWidget {
  final PostModel post;

  const PostMenu({
    super.key,
    required this.post,
  });

  bool get isOwner => false; // ⬅ placeholder

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'copy',
          child: Text('Copy link'),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Text('Report'),
        ),
        if (isOwner)
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
