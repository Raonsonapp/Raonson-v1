import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import 'comment_item.dart';

class CommentsScreen extends StatelessWidget {
  final PostModel post;
  final List<CommentModel> comments;

  const CommentsScreen({
    super.key,
    required this.post,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: comments.length,
        itemBuilder: (_, i) {
          return CommentItem(comment: comments[i]);
        },
      ),
    );
  }
}
