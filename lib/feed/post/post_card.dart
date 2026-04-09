import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ── Like toggle ─────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    _likeLoading = true;
    final wasLiked = _liked;
    setState(() { _liked = !wasLiked; _likeCount += _liked ? 1 : -1; });
    try {
      final res = await ApiClient.instance.post('/posts/${widget.post.id}/like');
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        setState(() {
          _liked     = body['liked']      ?? _liked;
          _likeCount = body['likesCount'] ?? _likeCount;
        });
      } else {
        setState(() { _liked = wasLiked; _likeCount += wasLiked ? 1 : -1; });
      }
    } catch (_) {
      setState(() { _liked = wasLiked; _likeCount += wasLiked ? 1 : -1; });
    }
    _likeLoading = false;
  }

  // ── Save toggle ─────────────────────────────────────────────────
  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !was);
    try {
      final res = await ApiClient.instance.post('/posts/${widget.post.id}/save');
      if (res.statusCode >= 400) setState(() => _saved = was);
    } catch (_) { setState(() => _saved = was); }
  }

  // ── Options bottom sheet ────────────────────────────────────────
  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.not_interested, color: Colors.white),
            title: const Text('Ба ман нишон надех', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            title: const Text('Шикоят кардан', style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined, color: Colors.white70),
            title: const Text('Аз лента пинхон кун', style: TextStyle(color: Colors.white70)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Share ───────────────────────────────────────────────────────
  void _showShare() {
    final url = 'https://raonson-v1.onrender.com/posts/preview/${widget.post.id}';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            title: const Text('Линкро нусха кун', style: TextStyle(color: Colors.white)),
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
            title: const Text('Дигар барномаҳо', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Share.share(url, subject: 'Raonson');
              setState(() => _shareCount++);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Comments ────────────────────────────────────────────────────
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

  // ── Time ago ────────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'ҳозир';
    if (d.inMinutes < 60) return '${d.inMinutes} дақиқа пеш';
    if (d.inHours   < 24) return '${d.inHours} соат пеш';
    if (d.inDays    < 7)  return '${d.inDays} рӯз пеш';
    return '${(d.inDays / 7).floor()} ҳафта пеш';
  }

  // ── Caption spans — hashtag сабз ───────────────────────────────
  List<TextSpan> _captionSpans(String text) {
    return text.split(' ').map((word) {
      if (word.startsWith('#')) {
        return TextSpan(
          text: '$word ',
          style: const TextStyle(
            color: AppColors.hashtag,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return TextSpan(
        text: '$word ',
        style: const TextStyle(color: AppColors.captionText, fontSize: 13.5),
      );
    }).toList();
  }

  // ── Format number: 3558 → "3 558" ──────────────────────────────
  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── HEADER: avatar · username · verified · time · ⋮ ──────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            // Avatar — доираи хурд мисли расм
            Avatar(imageUrl: post.user.avatar, size: 42, glowBorder: false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                // Username + verified badge
                Row(children: [
                  Text(post.user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: Colors.white,
                    )),
                  if (post.user.verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 16), // сабз мисли расм
                  ],
                ]),
                const SizedBox(height: 2),
                // "N соат пеш" мисли расм
                Text(
                  _timeAgo(post.createdAt),
                  style: const TextStyle(
                    color: AppColors.timeColor,
                    fontSize: 12.5,
                  ),
                ),
              ]),
            ),
            // ⋮ три точки
            GestureDetector(
              onTap: _showOptions,
              child: const Padding(padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert, color: Colors.white54, size: 20)),
            ),
          ]),
        ),

        // ── MEDIA ─────────────────────────────────────────────────────
        if (post.media.isNotEmpty)
          _MediaCarousel(media: post.media, isActive: widget.isActive),

        // ── ACTIONS — айнан мисли расм ────────────────────────────────
        // ♡ 3 558   💬 23   🔄 321   ↗ 435        🔖
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          child: Row(children: [

            // ♡ Heart outline — мисли расм
            _ActionBtn(
              onTap: _toggleLike,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _liked
                      ? const Icon(Icons.favorite_rounded,
                          key: ValueKey(true), color: Colors.red, size: 24)
                      : const Icon(Icons.favorite_border_rounded,
                          key: ValueKey(false), color: Colors.white, size: 24),
                ),
                if (_likeCount > 0) ...[
                  const SizedBox(width: 5),
                  Text(_fmt(_likeCount),
                    style: const TextStyle(
                      color: AppColors.actionCount, fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
                ],
              ]),
            ),

            const SizedBox(width: 4),

            // 💬 Speech bubble бо нуқтаҳо — мисли расм
            _ActionBtn(
              onTap: _openComments,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white, size: 22),
                if (_commentCount > 0) ...[
                  const SizedBox(width: 5),
                  Text(_fmt(_commentCount),
                    style: const TextStyle(
                      color: AppColors.actionCount, fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
                ],
              ]),
            ),

            const SizedBox(width: 4),

            // 🔄 Retweet — ду тир даврӣ мисли расм
            _ActionBtn(
              onTap: () => setState(() => _retweetCount++),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.repeat_rounded, color: Colors.white, size: 24),
                if (_retweetCount > 0) ...[
                  const SizedBox(width: 5),
                  Text(_fmt(_retweetCount),
                    style: const TextStyle(
                      color: AppColors.actionCount, fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
                ],
              ]),
            ),

            const SizedBox(width: 4),

            // ↗ Share — тири рост мисли расм
            _ActionBtn(
              onTap: _showShare,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.reply_rounded, // ← мисли ↗ тири расм
                    color: Colors.white, size: 24,
                    textDirection: TextDirection.rtl), // mirror → ↗
                if (_shareCount > 0) ...[
                  const SizedBox(width: 5),
                  Text(_fmt(_shareCount),
                    style: const TextStyle(
                      color: AppColors.actionCount, fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
                ],
              ]),
            ),

            const Spacer(),

            // 🔖 Bookmark — мисли расм
            _ActionBtn(
              onTap: _toggleSave,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _saved
                    ? const Icon(Icons.bookmark_rounded,
                        key: ValueKey(true), color: Colors.white, size: 23)
                    : const Icon(Icons.bookmark_border_rounded,
                        key: ValueKey(false), color: Colors.white, size: 23),
              ),
            ),
          ]),
        ),

        // ── CAPTION — username bold + text + #hashtag сабз ───────────
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: '${post.user.username} ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 13.5,
                  ),
                ),
                ..._captionSpans(post.caption),
              ]),
            ),
          ),

        // ── "Намоиш ҳама N шарх" мисли расм ─────────────────────────
        if (_commentCount > 0)
          GestureDetector(
            onTap: _openComments,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
              child: Text(
                'Намоиш ҳама $_commentCount шарх',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13.5,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 10),

        // Divider мисли расм — тунук
        const Divider(color: Color(0xFF1A1A1A), height: 1),
      ],
    );
  }
}

// ── Action button wrapper ───────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _ActionBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: child,
    ),
  );
}

// ── Media carousel ─────────────────────────────────────────────────
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
        height: w * 0.75, // landscape мисли расм (4:3)
        child: PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final url  = widget.media[i]['url']  ?? '';
            final type = widget.media[i]['type'] ?? 'image';
            if (url.isEmpty) return Container(color: AppColors.card);
            if (type == 'video') return _VideoItem(url: url, isActive: widget.isActive);
            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: const Color(0xFF1A1A1A),
                child: const Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white30))),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF1A1A1A),
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

// ── Video item ─────────────────────────────────────────────────────
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
    if (widget.isActive && _ready) _ctrl.play();
    else _ctrl.pause();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(color: Colors.black,
        child: const Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white30)));
    }
    return GestureDetector(
      onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(fit: BoxFit.cover,
          child: SizedBox(
            width: _ctrl.value.size.width,
            height: _ctrl.value.size.height,
            child: VideoPlayer(_ctrl))),
        if (!_ctrl.value.isPlaying)
          const Center(child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white70, size: 56)),
      ]),
    );
  }
}
