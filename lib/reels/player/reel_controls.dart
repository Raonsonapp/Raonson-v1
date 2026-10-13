import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../models/reel_model.dart';
import '../../widgets/avatar.dart';
import '../../core/api/api_client.dart';
import '../../core/content_sync.dart';
import '../../core/services/user_session.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/report_dialog.dart';
import '../../core/i18n/strings.dart';
import '../../core/links/deep_links.dart';
import '../../widgets/hashtag_suggestions.dart';
import '../../widgets/linked_text.dart';
import 'reel_location_chip.dart';
import '../../app/app_theme.dart';
import '../../core/services/follow_service.dart';
import '../widgets/reel_action_column.dart';
import '../widgets/reel_info_block.dart';

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
  // Ҳамаи рақамҳо аз ContentSync: reel-и аз профил/чат/огоҳинома
  // кушодашуда ҳамон лайк ва шумораеро нишон медиҳад, ки Reels ва Home.
  ContentState get _cs => ContentSync.instance.view(reel.id, reel.syncState);
  bool get _liked        => _cs.liked ?? false;
  bool get _saved        => _cs.saved ?? false;
  int  get _likeCount    => _cs.likesCount ?? 0;
  int  get _commentCount => _cs.commentsCount ?? 0;
  bool get _hideLikes    => _cs.hideLikes ?? false;
  bool get _commentsOff  => _cs.commentsOff ?? false;

  late ValueListenable<ContentState?> _syncNote;
  void _onSync() { if (mounted) setState(() {}); }

  ReelModel get reel => widget.reel;
  bool get _isOwner {
    final myId = UserSession.userId?.trim() ?? '';
    return myId.isNotEmpty && myId == reel.user.id.trim();
  }

  @override
  void initState() {
    super.initState();
    ContentSync.primeSoon(reel.primeSync);
    _syncNote = ContentSync.instance.watch(reel.id)..addListener(_onSync);
  }

  @override
  void didUpdateWidget(ReelControls old) {
    super.didUpdateWidget(old);
    if (old.reel.id == reel.id) return;
    _syncNote.removeListener(_onSync);
    _syncNote = ContentSync.instance.watch(reel.id)..addListener(_onSync);
    ContentSync.primeSoon(reel.primeSync);
  }

  @override
  void dispose() {
    _syncNote.removeListener(_onSync);
    super.dispose();
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    toggleReelLike(reel);
  }

  void _toggleSave() {
    HapticFeedback.selectionClick();
    final was = _saved;
    ContentSync.instance.report(reel.id, saved: !was);
    ApiClient.instance.post('/reels/${reel.id}/save').then((res) {
      if (res.statusCode >= 400) ContentSync.instance.report(reel.id, saved: was);
    }, onError: (_) => ContentSync.instance.report(reel.id, saved: was));
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
        // Рақам ба ContentSync — дар Reels/Home/профил ҳам нав мешавад.
        onAdded: (delta) => ContentSync.instance
            .bumpComments(reel.id, delta, base: _commentCount),
      ),
    );
  }

  // Хештег ва зикр — ҳамон қоидаи ягона, ки таби Reels дорад.
  List<InlineSpan> _captionSpans(String t) => linkedSpans(context, t,
      style: const TextStyle(color: Colors.white, fontSize: 14,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
      linkStyle: const TextStyle(color: AppColors.neonBlue, fontSize: 14,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)]));

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom;
    final caption = ContentSync.instance.get(reel.id)?.caption ?? reel.caption;
    return Stack(children: [
      // ── Тугмаҳои рост — ҳамон сутуни таби Reels ва Explore ──
      Positioned(
        right: 4,
        bottom: bottom + 20,
        child: ReelActionColumn(
          liked: _liked,
          likesLabel: reelLikesLabel(_likeCount, hidden: _hideLikes && !_isOwner),
          onLike: _toggleLike,
          // Шарҳҳо хомӯшанд → icon-и коммент нопадид мешавад.
          showComments: !_commentsOff,
          commentsCount: _commentCount,
          onComment: _openComments,
          sharesCount: _cs.sharesCount ?? 0,
          onShare: _share,
          saved: _saved,
          savesCount: reelSavesCount(reel.savesCount,
              savedAtLoad: reel.isSaved, savedNow: _saved),
          onSave: _toggleSave,
          onMore: _more,
          gap: mq.size.height < 640 ? 12 : 16,
        ),
      ),

      // ── Маълумоти корбар (поён-чап): ном → садо → тавсиф → ҷой ──
      Positioned(
        left: 14, right: 72, bottom: bottom + 18,
        child: ReelInfoBlock(
          author: ReelAuthorRow(
            userId: reel.user.id,
            username: reel.user.username,
            avatarUrl: reel.user.avatar,
            verified: reel.user.verified,
            isOwner: _isOwner,
            following: reel.user.isFollowing,
            followSource: FollowSource.reel(reel.id),
            onProfile: _openProfile,
          ),
          music: ReelMusicLine(
            title: reel.audioTitle,
            artist: reel.audioArtist,
            audioId: reel.audioId,
            username: reel.user.username,
            isPlaying: widget.isPlaying,
          ),
          caption: caption,
          captionSpans: _captionSpans,
          location: ReelLocationChip(reel: reel),
        ),
      ),
    ]);
  }
}

// ── Шарҳҳои reel — bottom sheet ──
class _ReelCommentsSheet extends StatefulWidget {
  final String reelId;
  final void Function(int delta) onAdded;
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
      // Сервер пешфарз 20 шарҳ медиҳад; ин варақа саҳифабандӣ надорад.
      final res = await ApiClient.instance.get(
          '/reels/${widget.reelId}/comments', query: const {'limit': '100'});
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
    final optimistic = <String, dynamic>{
      'text': text,
      'user': {'username': 'шумо'},
    };
    setState(() => _comments.insert(0, optimistic));
    widget.onAdded(1);
    var ok = false;
    try {
      final res = await ApiClient.instance
          .post('/reels/${widget.reelId}/comments', body: {'text': text});
      ok = res.statusCode < 400;
    } catch (_) {}
    if (!ok) {
      widget.onAdded(-1); // сервер нагирифт — рақам бармегардад
      // Шарҳи нафиристода дар рӯйхат намемонад; матн барои такрор бармегардад.
      if (!mounted) return;
      setState(() => _comments.remove(optimistic));
      _ctrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('common.failedRetry'))));
    }
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
                            subtitle: LinkedText((c['text'] ?? '').toString(),
                                style: const TextStyle(color: Colors.white)),
                          );
                        }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: HashtagSuggestions(controller: _ctrl),
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

/// Лайк/бекор кардани reel бо ContentSync (optimistic + баргардонӣ).
///
/// Ҳам тугмаи дил ва ҳам ду зарба дар экрани як reel инро истифода
/// мебаранд — пеш ду зарба дархости toggle-ро кӯр-кӯрона мефиристод ва
/// reel-и аллакай лайкшударо БЕКОР мекард, дар ҳоле ки дил сурх мемонд.
void toggleReelLike(ReelModel reel, {bool onlyLike = false}) {
  final cur = ContentSync.instance.view(reel.id, reel.syncState);
  final was = cur.liked ?? false;
  if (onlyLike && was) return;
  final wasCount = cur.likesCount ?? 0;
  final liked = !was;
  final count = (wasCount + (liked ? 1 : -1)).clamp(0, 1 << 31);
  ContentSync.instance.report(reel.id, liked: liked, likesCount: count);
  ApiClient.instance.post('/reels/${reel.id}/like').then((res) {
    if (res.statusCode >= 400) throw Exception('${res.statusCode}');
    final b = jsonDecode(res.body);
    if (b is Map && b['liked'] is bool) {
      ContentSync.instance.report(reel.id,
          liked: b['liked'] as bool,
          likesCount: (b['likesCount'] as num?)?.toInt());
    }
  }).catchError((_) {
    ContentSync.instance.report(reel.id, liked: was, likesCount: wasCount);
  });
}
