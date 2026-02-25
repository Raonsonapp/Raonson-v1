import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/post_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/api/api_client.dart';
import '../comments/comments_screen.dart';
import '../../app/app_theme.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late bool _saved;
  late int _likeCount;
  late int _commentCount;
  bool _likeLoading = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _saved = widget.post.isSaved;
    _likeCount = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    _likeLoading = true;
    // Optimistic update
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      final res = await ApiClient.instance.post('/posts/${widget.post.id}/like');
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        // Use server's actual count
        setState(() {
          _liked = body['liked'] ?? _liked;
          _likeCount = body['likesCount'] ?? _likeCount;
        });
      } else {
        // Revert
        setState(() { _liked = wasLiked; _likeCount += wasLiked ? 1 : -1; });
      }
    } catch (_) {
      setState(() { _liked = wasLiked; _likeCount += wasLiked ? 1 : -1; });
    }
    _likeLoading = false;
  }

  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !was);
    try {
      final res = await ApiClient.instance.post('/posts/${widget.post.id}/save');
      if (res.statusCode >= 400) setState(() => _saved = was);
    } catch (_) {
      setState(() => _saved = was);
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.not_interested, color: Colors.white),
            title: const Text('Ба ман нишон надех',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            title: const Text('Шикоят кардан',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined, color: Colors.white70),
            title: const Text('Аз лента пинхон кун',
                style: TextStyle(color: Colors.white70)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showShare() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Мубодила кардан',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white),
            title: const Text('Линкро нусха кун',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Линк нусха шуд!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.message_outlined, color: Colors.white),
            title: const Text('Ба дӯст фиристед',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: CommentsScreen(
          post: widget.post,
          onCommentAdded: () {
            setState(() => _commentCount++);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Avatar(imageUrl: post.user.avatar, size: 36, glowBorder: false),
            const SizedBox(width: 10),
            Expanded(child: Row(children: [
              Text(post.user.username, style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
              if (post.user.verified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 14),
              ],
            ])),
            GestureDetector(
              onTap: _showOptions,
              child: const Padding(padding: EdgeInsets.all(4),
                child: Icon(Icons.more_horiz, color: Colors.white60, size: 20)),
            ),
          ]),
        ),

        // MEDIA
        if (post.media.isNotEmpty) _MediaCarousel(media: post.media),

        // ACTIONS
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Row(children: [
            _Btn(onTap: _toggleLike, child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _liked
                  ? const Icon(Icons.favorite, key: ValueKey(true),
                      color: Colors.red, size: 26)
                  : const Icon(Icons.favorite_border, key: ValueKey(false),
                      color: Colors.white, size: 26),
            )),
            _Btn(onTap: () => _openComments(), child: const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 24)),
            _Btn(onTap: () => _showShare(), child: Transform.rotate(angle: -0.4,
              child: const Icon(Icons.send_outlined, color: Colors.white, size: 23))),
            const Spacer(),
            _Btn(onTap: _toggleSave, child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _saved
                  ? const Icon(Icons.bookmark, key: ValueKey(true),
                      color: Colors.white, size: 26)
                  : const Icon(Icons.bookmark_border, key: ValueKey(false),
                      color: Colors.white, size: 26),
            )),
          ]),
        ),

        // LIKES & COMMENTS COUNT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Text('$_likeCount likes', style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _openComments,
              child: Text(
                '$_commentCount комментария',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ]),
        ),

        // CAPTION
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
            child: RichText(text: TextSpan(children: [
              TextSpan(text: '${post.user.username} ',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.white, fontSize: 13)),
              TextSpan(text: post.caption,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
          ),

        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1),
      ],
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
      child: Padding(padding: const EdgeInsets.all(6), child: child));
}

class _MediaCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  const _MediaCarousel({required this.media});
  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Stack(alignment: Alignment.bottomCenter, children: [
      SizedBox(
        height: w,
        child: PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final url = widget.media[i]['url'] ?? '';
            if (url.isEmpty) return Container(color: AppColors.card);
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(
                color: AppColors.card,
                child: const Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white30))),
              errorWidget: (_, url, err) => Container(
                color: AppColors.card,
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        color: Colors.white30, size: 48),
                    const SizedBox(height: 8),
                    Text(url.length > 40 ? url.substring(0, 40) : url,
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                        textAlign: TextAlign.center),
                  ]),
              ),
            );
          },
        ),
      ),
      if (widget.media.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.media.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _current == i ? AppColors.neonBlue : Colors.white38,
                ),
              )),
          ),
        ),
    ]);
  }
}
