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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // ── Like (Heart outline → filled on tap) ──
          _ActionBtn(
            onTap: () => setState(() => _liked = !_liked),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _liked
                  ? const Icon(Icons.favorite,
                      key: ValueKey('liked'), color: Colors.red, size: 26)
                  : const Icon(Icons.favorite_border,
                      key: ValueKey('unliked'), color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 4),
          // ── Comment (speech bubble) ──
          _ActionBtn(
            onTap: () {},
            child: const Icon(Icons.mode_comment_outlined,
                color: Colors.white, size: 25),
          ),
          const SizedBox(width: 4),
          // ── Share (paper plane / direct) ──
          _ActionBtn(
            onTap: () {},
            child: Transform.rotate(
              angle: -0.4,
              child: const Icon(Icons.send_outlined,
                  color: Colors.white, size: 24),
            ),
          ),
          const Spacer(),
          // ── Bookmark ──
          _ActionBtn(
            onTap: () => setState(() => _saved = !_saved),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _saved
                  ? const Icon(Icons.bookmark,
                      key: ValueKey('saved'), color: Colors.white, size: 26)
                  : const Icon(Icons.bookmark_border,
                      key: ValueKey('unsaved'), color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _ActionBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: child,
        ),
      );
}
