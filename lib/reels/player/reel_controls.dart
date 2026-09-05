import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../models/reel_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/report_dialog.dart';
import '../../core/i18n/strings.dart';
import '../../core/links/deep_links.dart';

// Overlay-и пурраи reel — мисли Instagram (иконкаҳои худамон + тугмаҳои корӣ).
class ReelControls extends StatefulWidget {
  final ReelModel reel;
  final bool isPlaying;

  const ReelControls({
    super.key,
    required this.reel,
    required this.isPlaying,
  });

  @override
  State<ReelControls> createState() => _ReelControlsState();
}

class _ReelControlsState extends State<ReelControls> {
  late bool _liked;
  late bool _saved;
  late int  _likeCount;
  late int  _commentCount;

  ReelModel get reel => widget.reel;
  bool get _isOwner {
    final myId = UserSession.userId?.trim() ?? '';
    return myId.isNotEmpty && myId == reel.user.id.trim();
  }

  @override
  void initState() {
    super.initState();
    _liked = reel.isLiked;
    _saved = reel.isSaved;
    _likeCount = reel.likesCount;
    _commentCount = reel.commentsCount;
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    ApiClient.instance.post('/reels/${reel.id}/like').then((_) {}, onError: (_) {});
  }

  void _toggleSave() {
    HapticFeedback.selectionClick();
    setState(() => _saved = !_saved);
    ApiClient.instance.post('/reels/${reel.id}/save').then((_) {}, onError: (_) {});
  }

  // Пештар суроғаи файли видео фиристода мешуд: он барномаро
  // намекушод ва гиранда танҳо як файлро мегирифт.
  void _share() => Share.share(DeepLinks.share(DeepLinkKind.reel, reel.id));

  void _openProfile() =>
      Navigator.pushNamed(context, '/user-profile', arguments: reel.user.id);

  void _more() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(AppIcons.flag_outlined, color: Colors.white),
            title: Text(tr('ui.79cab6251d'),
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              final result = await ReportDialog.showWithDescription(context);
              if (result == null) return;
              ApiClient.instance
                  .post('/reels/${reel.id}/report',
                      body: {'reason': result.reason, 'description': result.description})
                  .then((_) {}, onError: (_) {});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr('ui.507bb6dd66')),
                    duration: Duration(seconds: 2)));
              }
            },
          ),
          ListTile(
            leading: Icon(AppIcons.link_rounded, color: Colors.white),
            title: Text(tr('ui.16d42947af'),
                style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _share(); },
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
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReelCommentsSheet(
        reelId: reel.id,
        onAdded: () { if (mounted) setState(() => _commentCount++); },
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // ── Тугмаҳои рост ──
      Positioned(
        right: 10,
        bottom: 90,
        child: Column(children: [
          _SvgBtn(
              asset: _liked
                  ? 'assets/icons/heart_filled.svg'
                  : 'assets/icons/heart.svg',
              color: _liked ? const Color(0xFFFF3040) : Colors.white,
              label: (reel.hideLikes && !_isOwner)
                  ? 'Лайкҳо'
                  : _fmt(_likeCount),
              onTap: _toggleLike),
          const SizedBox(height: 18),
          // Шарҳҳо хомӯшанд → icon-и коммент нопадид мешавад.
          if (!reel.commentsDisabled) ...[
            _SvgBtn(
                asset: 'assets/icons/comment.svg',
                label: _fmt(_commentCount),
                onTap: _openComments),
            const SizedBox(height: 18),
          ],
          _SvgBtn(asset: 'assets/icons/share.svg', onTap: _share),
          const SizedBox(height: 18),
          _SvgBtn(
              asset: _saved
                  ? 'assets/icons/save_filled.svg'
                  : 'assets/icons/save.svg',
              onTap: _toggleSave),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _more,
            child: const Icon(AppIcons.more_vert, color: Colors.white, size: 26),
          ),
        ]),
      ),

      // ── Маълумоти корбар (поён-чап) ──
      Positioned(
        left: 14, right: 80, bottom: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              GestureDetector(
                onTap: _openProfile,
                child: Avatar(
                  imageUrl: reel.user.avatar,
                  name: reel.user.username,
                  size: 34,
                  glowBorder: reel.user.hasStory,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openProfile,
                child: Text(reel.user.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (reel.user.verified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 14, color: Colors.white),
              ],
            ]),
            if (reel.caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reel.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(children: [
              SvgPicture.asset('assets/icons/music.svg',
                  width: 13, height: 13,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  reel.audioTitle.isNotEmpty
                      ? (reel.audioArtist.isNotEmpty
                          ? '${reel.audioTitle} • ${reel.audioArtist}'
                          : reel.audioTitle)
                      : 'Аудиои оригиналӣ',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ]),
          ],
        ),
      ),
    ]);
  }
}

class _SvgBtn extends StatelessWidget {
  final String asset;
  final String? label;
  final Color color;
  final VoidCallback onTap;
  const _SvgBtn(
      {required this.asset, this.label, this.color = Colors.white, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(children: [
        SvgPicture.asset(asset, width: 30, height: 30,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!,
              style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

// ── Шарҳҳои reel — bottom sheet ──
class _ReelCommentsSheet extends StatefulWidget {
  final String reelId;
  final VoidCallback onAdded;
  const _ReelCommentsSheet({required this.reelId, required this.onAdded});
  @override
  State<_ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<_ReelCommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res =
          await ApiClient.instance.get('/reels/${widget.reelId}/comments');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body is List ? body : (body['comments'] ?? [])) as List;
        setState(() {
          _comments = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _comments.insert(0, {
          'text': text,
          'user': {'username': 'шумо'},
        }));
    widget.onAdded();
    try {
      await ApiClient.instance
          .post('/reels/${widget.reelId}/comments', body: {'text': text});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          Text(tr('ui.8be35deea4'),
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 15)),
          const Divider(color: Colors.white12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white30, strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(
                        child: Text(tr('ui.656a3f32d0'),
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final u = (c['user'] ?? {}) as Map;
                          return ListTile(
                            leading: Avatar(
                                imageUrl: (u['avatar'] ?? '').toString(),
                                name: (u['username'] ?? '').toString(),
                                size: 34),
                            title: Text((u['username'] ?? '').toString(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            subtitle: Text((c['text'] ?? '').toString(),
                                style: const TextStyle(color: Colors.white)),
                          );
                        }),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 1000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: tr('ui.945641e96c'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.send_rounded, color: Color(0xFF1D9BF0)),
                onPressed: _send,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
