import 'package:flutter/material.dart';

import '../../models/comment_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/api/api_client.dart';

class CommentItem extends StatefulWidget {
  final CommentModel comment;
  const CommentItem({super.key, required this.comment});

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  late bool _liked;

  @override
  void initState() {
    super.initState();
    _liked = widget.comment.isLiked;
  }

  Future<void> _toggleLike() async {
    final was = _liked;
    setState(() => _liked = !was);
    try {
      final res = await ApiClient.instance.post(
          '/comments/${widget.comment.id}/like');
      if (res.statusCode >= 400) setState(() => _liked = was);
    } catch (_) {
      setState(() => _liked = was);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(imageUrl: widget.comment.user.avatar, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(widget.comment.user.username,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              if (widget.comment.user.verified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 12),
              ],
            ]),
            const SizedBox(height: 2),
            Text(widget.comment.text,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(widget.comment.timeAgo,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        GestureDetector(
          onTap: _toggleLike,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                _liked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(_liked),
                size: 18,
                color: _liked ? Colors.red : Colors.white38,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
