import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../app/app_theme.dart';

class PostActions extends StatefulWidget {
  final PostModel post;
  const PostActions({super.key, required this.post});

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  late bool _liked;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _saved = widget.post.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          // Heart
          IconButton(
            onPressed: () => setState(() => _liked = !_liked),
            icon: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              color: _liked ? AppColors.red : Colors.white,
              size: 26,
            ),
          ),
          // Comment
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline,
                color: Colors.white, size: 24),
          ),
          // Share (send)
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.send_rounded,
                color: Colors.white, size: 24),
          ),
          const Spacer(),
          // Bookmark
          IconButton(
            onPressed: () => setState(() => _saved = !_saved),
            icon: Icon(
              _saved ? Icons.bookmark : Icons.bookmark_border,
              color: _saved ? AppColors.neonBlue : Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
