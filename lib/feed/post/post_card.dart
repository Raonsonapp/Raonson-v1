import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/post_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/api/api_client.dart';
import '../comments/comments_screen.dart';
import '../../app/app_theme.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final bool isActive;
  const PostCard({super.key, required this.post, this.isActive = true});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late bool _saved;
  late int  _likeCount;
  late int  _commentCount;
  int  _retweetCount = 0;
  int  _shareCount   = 0;
  bool _likeLoading  = false;

  @override
  void initState() {
    super.initState();
    _liked        = widget.post.isLiked;
    _saved        = widget.post.isSaved;
    _likeCount    = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    _likeLoading = true;
    final was = _liked;
    setState(() { _liked = !was; _likeCount += _liked ? 1 : -1; });
    try {
      final res = await ApiClient.instance.post('/posts/${widget.post.id}/like');
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        setState(() {
          _liked     = b['liked']      ?? _liked;
          _likeCount = b['likesCount'] ?? _likeCount;
        });
      } else {
        setState(() { _liked = was; _likeCount += was ? 1 : -1; });
      }
    } catch (_) {
      setState(() { _liked = was; _likeCount += was ? 1 : -1; });
    }
    _likeLoading = false;
  }

  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !was);
    try {
      final res = await ApiClient.instance.post('/posts/${widget.post.id}/save');
      if (res.statusCode >= 400) setState(() => _saved = was);
    } catch (_) { setState(() => _saved = was); }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10),
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
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showShare() {
    final url = 'https://raonson-v1.onrender.com/posts/preview/${widget.post.id}';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Мубодила', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.white12,
              child: Icon(Icons.link, color: Colors.white, size: 20)),
          title: const Text('Линкро нусха кун',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Линк нусха шуд ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)));
          },
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.white12,
              child: Icon(Icons.share_outlined, color: Colors.white, size: 20)),
          title: const Text('Дигар барномаҳо',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Share.share(url);
            setState(() => _shareCount++);
          },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: CommentsScreen(
          post: widget.post,
          onCommentAdded: () => setState(() => _commentCount++),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'ҳозир';
    if (d.inMinutes < 60) return '${d.inMinutes} дақиқа пеш';
    if (d.inHours   < 24) return '${d.inHours} соат пеш';
    if (d.inDays    < 7)  return '${d.inDays} рӯз пеш';
    return '${(d.inDays / 7).floor()} ҳафта пеш';
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  List<InlineSpan> _captionSpans(String text) {
    return text.split(' ').map((word) {
      if (word.startsWith('#')) {
        return TextSpan(text: '$word ',
          style: const TextStyle(color: AppColors.hashtag, fontSize: 14,
              fontWeight: FontWeight.w500));
      }
      return TextSpan(text: '$word ',
        style: const TextStyle(color: AppColors.captionText, fontSize: 14));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── HEADER ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Row(children: [
          Avatar(imageUrl: post.user.avatar, size: 44, glowBorder: false),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(post.user.username,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 15, color: Colors.white)),
                if (post.user.verified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 16),
                ],
              ]),
              const SizedBox(height: 2),
              Text(_timeAgo(post.createdAt),
                  style: const TextStyle(color: AppColors.timeColor, fontSize: 12.5)),
            ],
          )),
          GestureDetector(
            onTap: _showOptions,
            child: const Padding(padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert, color: AppColors.grey, size: 20)),
          ),
        ]),
      ),

      // ── MEDIA ────────────────────────────────────────────────────
      if (post.media.isNotEmpty)
        _MediaCarousel(media: post.media, isActive: widget.isActive),

      // ── ACTIONS — айнан мисли расм 1 ─────────────────────────────
      // ♡ 3558  ◯ 23  ↩↪ 321  ↗ 435                    🔖
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Row(children: [

          // ♡ Heart outline → filled red
          _ActionBtn(
            onTap: _toggleLike,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _liked
                  ? SvgPicture.asset('assets/icons/heart_filled.svg',
                      key: const ValueKey(true), width: 24, height: 24)
                  : SvgPicture.asset('assets/icons/heart.svg',
                      key: const ValueKey(false), width: 24, height: 24,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn)),
            ),
            count: _likeCount,
            fmt: _fmt,
          ),

          const SizedBox(width: 4),

          // ◯ Comment — тунук доира мисли расм 1
          _ActionBtn(
            onTap: _openComments,
            child: SvgPicture.asset('assets/icons/comment.svg',
              width: 23, height: 23,
              colorFilter: const ColorFilter.mode(
                  Colors.white, BlendMode.srcIn)),
            count: _commentCount,
            fmt: _fmt,
          ),

          const SizedBox(width: 4),

          // ↩↪ Retweet
          _ActionBtn(
            onTap: () => setState(() => _retweetCount++),
            child: SvgPicture.asset('assets/icons/retweet.svg',
              width: 24, height: 24,
              colorFilter: const ColorFilter.mode(
                  Colors.white, BlendMode.srcIn)),
            count: _retweetCount,
            fmt: _fmt,
          ),

          const SizedBox(width: 4),

          // ↗ Share
          _ActionBtn(
            onTap: _showShare,
            child: SvgPicture.asset('assets/icons/share.svg',
              width: 23, height: 23,
              colorFilter: const ColorFilter.mode(
                  Colors.white, BlendMode.srcIn)),
            count: _shareCount,
            fmt: _fmt,
          ),

          const Spacer(),

          // 🔖 Bookmark
          _ActionBtn(
            onTap: _toggleSave,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _saved
                  ? SvgPicture.asset('assets/icons/save_filled.svg',
                      key: const ValueKey(true), width: 23, height: 23,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn))
                  : SvgPicture.asset('assets/icons/save.svg',
                      key: const ValueKey(false), width: 23, height: 23,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn)),
            ),
            count: 0,
            fmt: _fmt,
          ),
        ]),
      ),

      // ── CAPTION ──────────────────────────────────────────────────
      if (post.caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: RichText(
            text: TextSpan(children: [
              TextSpan(text: '${post.user.username} ',
                style: const TextStyle(fontWeight: FontWeight.w700,
                    color: Colors.white, fontSize: 14)),
              ..._captionSpans(post.caption),
            ]),
          ),
        ),

      // ── "Намоиш ҳама N шарх" ─────────────────────────────────────
      if (_commentCount > 0)
        GestureDetector(
          onTap: _openComments,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: Text('Намоиш ҳама $_commentCount шарх',
              style: const TextStyle(color: AppColors.timeColor, fontSize: 13.5)),
          ),
        )
      else
        const SizedBox(height: 10),

      const Divider(color: Color(0xFF1A1A1A), height: 1),
    ]);
  }
}

// ── Action button бо шумора ─────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final int count;
  final String Function(int) fmt;

  const _ActionBtn({
    required this.onTap,
    required this.child,
    required this.count,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          child,
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(fmt(count),
              style: const TextStyle(color: AppColors.actionCount,
                  fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ]),
      ),
    );
  }
}

// ── Media Carousel ─────────────────────────────────────────────────
class _MediaCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  final bool isActive;
  const _MediaCarousel({required this.media, this.isActive = true});
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
        height: w * 0.75,
        child: PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final url  = widget.media[i]['url']  ?? '';
            final type = widget.media[i]['type'] ?? 'image';
            if (url.isEmpty) return Container(color: const Color(0xFF111111));
            if (type == 'video') {
              return _VideoItem(url: url, isActive: widget.isActive);
            }
            return CachedNetworkImage(
              imageUrl: url, fit: BoxFit.cover,
              width: double.infinity, height: double.infinity,
              placeholder: (_, __) => Container(color: const Color(0xFF111111),
                child: const Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white30))),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF111111),
                child: const Center(child: Icon(Icons.broken_image_outlined,
                    color: Colors.white30, size: 48))),
            );
          },
        ),
      ),
      if (widget.media.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.media.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _current == i ? Colors.white : Colors.white38,
                ),
              )),
          ),
        ),
    ]);
  }
}

// ── Video Item ─────────────────────────────────────────────────────
class _VideoItem extends StatefulWidget {
  final String url;
  final bool isActive;
  const _VideoItem({required this.url, this.isActive = true});
  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          if (widget.isActive) _ctrl.play();
          _ctrl.setLooping(true);
        }
      });
  }

  @override
  void didUpdateWidget(_VideoItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && _ready) _ctrl.play(); else _ctrl.pause();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return Container(color: Colors.black,
      child: const Center(child: CircularProgressIndicator(
          strokeWidth: 2, color: Colors.white30)));
    return GestureDetector(
      onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(fit: BoxFit.cover,
          child: SizedBox(width: _ctrl.value.size.width,
              height: _ctrl.value.size.height, child: VideoPlayer(_ctrl))),
        if (!_ctrl.value.isPlaying)
          const Center(child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white70, size: 56)),
      ]),
    );
  }
}
