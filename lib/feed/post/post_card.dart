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
    final postUrl = 'https://raonson-v1.onrender.com/posts/preview/${widget.post.id}';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Мубодила', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white12,
                child: Icon(Icons.link, color: Colors.white, size: 20)),
            title: const Text('Линкро нусха кун',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: postUrl));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Линк нусха шуд ✓'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2)),
              );
            },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white12,
                child: Icon(Icons.share_outlined, color: Colors.white, size: 20)),
            title: const Text('Дигар барномаҳо',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Share.share(postUrl, subject: 'Raonson');
            },
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

        // ACTIONS — icon + count next to each icon
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Row(children: [
            // Like icon + count
            GestureDetector(
              onTap: _toggleLike,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _liked
                        ? const Icon(Icons.favorite, key: ValueKey(true),
                            color: Colors.red, size: 24)
                        : const Icon(Icons.favorite_border, key: ValueKey(false),
                            color: Colors.white, size: 24),
                  ),
                  if (_likeCount > 0) ...[
                    const SizedBox(width: 4),
                    Text('$_likeCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 4),
            // Comment icon + count
            GestureDetector(
              onTap: _openComments,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mode_comment_outlined,
                      color: Colors.white, size: 23),
                  if (_commentCount > 0) ...[
                    const SizedBox(width: 4),
                    Text('$_commentCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 4),
            // Share icon
            GestureDetector(
              onTap: _showShare,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Transform.rotate(angle: -0.4,
                    child: const Icon(Icons.send_outlined,
                        color: Colors.white, size: 23)),
              ),
            ),
            const Spacer(),
            // Save icon
            GestureDetector(
              onTap: _toggleSave,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _saved
                      ? const Icon(Icons.bookmark, key: ValueKey(true),
                          color: Colors.white, size: 24)
                      : const Icon(Icons.bookmark_border, key: ValueKey(false),
                          color: Colors.white, size: 24),
                ),
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
            final type = widget.media[i]['type'] ?? 'image';
            if (url.isEmpty) return Container(color: AppColors.card);
            if (type == 'video') {
              return _VideoItem(url: url);
            }
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
                child: const Center(child: Icon(Icons.broken_image_outlined,
                    color: Colors.white30, size: 48)),
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

class _VideoItem extends StatefulWidget {
  final String url;
  const _VideoItem({required this.url});

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
          _ctrl.setLooping(true);
          _ctrl.play();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2)),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _ctrl.value.size.width,
          height: _ctrl.value.size.height,
          child: VideoPlayer(_ctrl),
        ),
      ),
      // Play/pause on tap
      GestureDetector(
        onTap: () {
          setState(() {
            _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
          });
        },
        child: AnimatedOpacity(
          opacity: _ctrl.value.isPlaying ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: const Center(
            child: Icon(Icons.play_circle_fill,
                color: Colors.white70, size: 64),
          ),
        ),
      ),
    ]);
  }
}


// ─────────────────────────────────────────────
// Instagram 2026 Style Action Button
// ─────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final int count;
  final Color activeColor;
  final bool isActive;

  const _ActionBtn({
    required this.onTap,
    required this.icon,
    this.count = 0,
    this.activeColor = Colors.white,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(
              count >= 1000
                  ? '${(count / 1000).toStringAsFixed(1)}K'
                  : '$count',
              style: TextStyle(
                color: isActive ? activeColor : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Instagram 2026 Icon Painter
// ─────────────────────────────────────────────
class _IgIcon extends StatelessWidget {
  final _IgIconType type;
  final bool filled;
  final Color color;
  final double size;

  const _IgIcon._({
    required this.type,
    this.filled = false,
    this.color = Colors.white,
    this.size = 25,
  });

  factory _IgIcon.heart({bool filled = false}) => _IgIcon._(
      type: _IgIconType.heart,
      filled: filled,
      color: filled ? const Color(0xFFFF3040) : Colors.white);

  factory _IgIcon.comment() =>
      const _IgIcon._(type: _IgIconType.comment);

  factory _IgIcon.share() =>
      const _IgIcon._(type: _IgIconType.share);

  factory _IgIcon.save({bool filled = false}) =>
      _IgIcon._(type: _IgIconType.save, filled: filled);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.elasticOut)),
        child: child,
      ),
      child: CustomPaint(
        key: ValueKey('${type.name}_$filled'),
        size: Size(size, size),
        painter: _IgIconPainter(type: type, filled: filled, color: color),
      ),
    );
  }
}

enum _IgIconType { heart, comment, share, save }

class _IgIconPainter extends CustomPainter {
  final _IgIconType type;
  final bool filled;
  final Color color;

  const _IgIconPainter({
    required this.type,
    required this.filled,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case _IgIconType.heart:
        _drawHeart(canvas, size);
        break;
      case _IgIconType.comment:
        _drawComment(canvas, size);
        break;
      case _IgIconType.share:
        _drawShare(canvas, size);
        break;
      case _IgIconType.save:
        _drawSave(canvas, size);
        break;
    }
  }

  Paint _paint({bool stroke = true}) => Paint()
    ..color = color
    ..strokeWidth = 1.9
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = stroke && !filled ? PaintingStyle.stroke : PaintingStyle.fill
    ..isAntiAlias = true;

  // ── HEART ──────────────────────────────────
  void _drawHeart(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final path = Path();
    // Instagram-style heart shape
    path.moveTo(w * 0.5, h * 0.82);
    path.cubicTo(w * 0.1, h * 0.55, w * -0.05, h * 0.35,
        w * 0.15, h * 0.2);
    path.cubicTo(w * 0.28, h * 0.08, w * 0.42, h * 0.1,
        w * 0.5, h * 0.22);
    path.cubicTo(w * 0.58, h * 0.1, w * 0.72, h * 0.08,
        w * 0.85, h * 0.2);
    path.cubicTo(w * 1.05, h * 0.35, w * 0.9, h * 0.55,
        w * 0.5, h * 0.82);
    path.close();
    canvas.drawPath(path, _paint(stroke: true));
  }

  // ── COMMENT BUBBLE ──────────────────────────
  void _drawComment(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final r = w * 0.14;
    final paint = _paint(stroke: true)
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.06, w * 0.92, h * 0.72),
      Radius.circular(r),
    );
    canvas.drawRRect(rect, paint);

    // Tail at bottom left
    final tail = Path()
      ..moveTo(w * 0.18, h * 0.78)
      ..lineTo(w * 0.08, h * 0.94)
      ..lineTo(w * 0.34, h * 0.78);
    canvas.drawPath(tail, paint);
  }

  // ── SHARE (Paper plane) ─────────────────────
  void _drawShare(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final paint = _paint(stroke: true)
      ..style = PaintingStyle.stroke;

    // Paper plane Instagram style
    final body = Path()
      ..moveTo(w * 0.95, h * 0.05)
      ..lineTo(w * 0.05, h * 0.48)
      ..lineTo(w * 0.38, h * 0.58)
      ..lineTo(w * 0.95, h * 0.05);
    canvas.drawPath(body, paint);

    final tail = Path()
      ..moveTo(w * 0.38, h * 0.58)
      ..lineTo(w * 0.42, h * 0.92)
      ..lineTo(w * 0.62, h * 0.72)
      ..lineTo(w * 0.95, h * 0.05);
    canvas.drawPath(tail, paint);

    // Center fold line
    final fold = Path()
      ..moveTo(w * 0.38, h * 0.58)
      ..lineTo(w * 0.65, h * 0.33);
    canvas.drawPath(fold, paint);
  }

  // ── SAVE / BOOKMARK ─────────────────────────
  void _drawSave(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.06)
      ..lineTo(w * 0.82, h * 0.06)
      ..lineTo(w * 0.82, h * 0.94)
      ..lineTo(w * 0.5, h * 0.72)
      ..lineTo(w * 0.18, h * 0.94)
      ..close();
    canvas.drawPath(path, _paint(stroke: true));
  }

  @override
  bool shouldRepaint(_IgIconPainter old) =>
      old.filled != filled || old.color != color;
}
