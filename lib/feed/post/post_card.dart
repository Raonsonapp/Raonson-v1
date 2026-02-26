import 'dart:convert';
import 'package:flutter/material.dart';
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
    final postUrl = 'https://raonson.app/post/\${widget.post.id}';
    final text = widget.post.caption.isNotEmpty
        ? '\${widget.post.caption}\n\$postUrl'
        : postUrl;
    Share.share(text, subject: 'Raonson пост');
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

        // LIKES & COMMENTS COUNT - Instagram style
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Likes
              if (_likeCount > 0)
                Text(
                  _likeCount == 1 ? '1 нафар писанд кард' : '$_likeCount нафар писанд карданд',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white),
                ),
              // Comments
              if (_commentCount > 0)
                GestureDetector(
                  onTap: _openComments,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      _commentCount == 1
                          ? 'Нишон додани 1 комментария'
                          : 'Нишон додани ҳамаи $_commentCount комментария',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
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
