import 'dart:convert';
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
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.comment.isLiked;
    _likesCount = widget.comment.likesCount;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likesCount += _liked ? 1 : -1;
    });

    // Heart animation
    if (_liked) _showHeart();

    try {
      final res = await ApiClient.instance
          .post('/comments/${widget.comment.id}/like');
      if (res.statusCode >= 400) {
        setState(() {
          _liked = wasLiked;
          _likesCount += wasLiked ? 1 : -1;
        });
      } else {
        final body = jsonDecode(res.body);
        // Sync with server value
        final serverLiked = body['liked'] as bool? ?? _liked;
        if (serverLiked != _liked) {
          setState(() {
            _liked = serverLiked;
            _likesCount += serverLiked ? 1 : -1;
          });
        }
      }
    } catch (_) {
      setState(() {
        _liked = wasLiked;
        _likesCount += wasLiked ? 1 : -1;
      });
    }
  }

  void _showHeart() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HeartPop(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
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
                      fontWeight: FontWeight.w600, color: Colors.white,
                      fontSize: 13)),
              if (widget.comment.user.verified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 12),
              ],
            ]),
            const SizedBox(height: 2),
            Text(widget.comment.text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 6),
            // Time + like count row
            Row(children: [
              Text(widget.comment.timeAgo,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
              if (_likesCount > 0) ...[
                const SizedBox(width: 12),
                Text(
                  '$_likesCount ${_likesCount == 1 ? 'лайк' : 'лайк'}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ]),
          ]),
        ),
        // Like button
        GestureDetector(
          onTap: _toggleLike,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim, child: child),
                child: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(_liked),
                  size: 18,
                  color: _liked ? Colors.red : Colors.white38,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Small heart pop animation
class _HeartPop extends StatefulWidget {
  final VoidCallback onDone;
  const _HeartPop({required this.onDone});
  @override
  State<_HeartPop> createState() => _HeartPopState();
}

class _HeartPopState extends State<_HeartPop>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _scale = Tween(begin: 0.5, end: 1.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.5, 1.0)));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: const Icon(Icons.favorite,
              color: Colors.red, size: 40),
        ),
      ),
    ));
  }
}
