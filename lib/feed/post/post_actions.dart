import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../core/api/api_client.dart';

class PostActions extends StatefulWidget {
  final PostModel post;
  const PostActions({super.key, required this.post});

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  late bool _liked;
  late bool _saved;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _saved = widget.post.isSaved;
    _likeCount = widget.post.likesCount;
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      await ApiClient.instance.post('/posts/${widget.post.id}/like');
    } catch (_) {
      // revert on error
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try {
      await ApiClient.instance.post('/posts/${widget.post.id}/save');
    } catch (_) {
      setState(() => _saved = !_saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        children: [
          // Like
          _Btn(
            onTap: _toggleLike,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _liked
                  ? const Icon(Icons.favorite,
                      key: ValueKey(true), color: Colors.red, size: 26)
                  : const Icon(Icons.favorite_border,
                      key: ValueKey(false), color: Colors.white, size: 26),
            ),
          ),
          // Comment
          _Btn(
            onTap: () {},
            child: const Icon(Icons.mode_comment_outlined,
                color: Colors.white, size: 24),
          ),
          // Share
          _Btn(
            onTap: () {},
            child: Transform.rotate(
              angle: -0.4,
              child: const Icon(Icons.send_outlined,
                  color: Colors.white, size: 23),
            ),
          ),
          const Spacer(),
          // Bookmark
          _Btn(
            onTap: _toggleSave,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _saved
                  ? const Icon(Icons.bookmark,
                      key: ValueKey(true), color: Colors.white, size: 26)
                  : const Icon(Icons.bookmark_border,
                      key: ValueKey(false), color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Btn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      );
}
