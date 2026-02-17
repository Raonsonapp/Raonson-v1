import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import 'comment_item.dart';
import 'comment_input.dart';

class CommentsScreen extends StatelessWidget {
  final PostModel post;

  const CommentsScreen({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        elevation: 1,
      ),
      body: Column(
        children: [
          // ================= COMMENTS LIST =================
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: post.comments.length,
              itemBuilder: (context, index) {
                final comment = post.comments[index];
                return CommentItem(comment: comment);
              },
            ),
          ),

          // ================= INPUT =================
          CommentInput(
            postId: post.id,
          ),
        ],
      ),
    );
  }
}
