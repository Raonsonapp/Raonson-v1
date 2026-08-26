// lib/stories/story_group_viewer.dart
// Multi-story group viewer — мисли Instagram
// Groups = List<List<StoryModel>>, navigate between users with swipe

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/story_model.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/report_dialog.dart';
import '../core/i18n/strings.dart';
import '../chat/share/share_to_chat_row.dart';

class StoryGroupViewer extends StatefulWidget {
  final List<List<StoryModel>> groups;
  final int initialGroupIndex;
  final void Function(String storyId)? onViewed;

  const StoryGroupViewer({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
    this.onViewed,
  });

  @override
  State<StoryGroupViewer> createState() => _StoryGroupViewerState();
}

class _StoryGroupViewerState extends State<StoryGroupViewer> {
  late PageController _pageCtrl;
  late int _groupIdx;

  @override
  void initState() {
    super.initState();
    _groupIdx = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    _pageCtrl = PageController(initialPage: _groupIdx);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextGroup() {
    if (_groupIdx < widget.groups.length - 1) {
      _groupIdx++;
        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevGroup() {
    if (_groupIdx > 0) {
      _groupIdx--;
        _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageCtrl,
      itemCount: widget.groups.length,
      onPageChanged: (i) => setState(() { _groupIdx = i; }),
      itemBuilder: (_, i) {
        return KeyedSubtree(
          key: ValueKey('group_$i'),
          child: _SingleGroupViewer(
            stories:    widget.groups[i],
            onNext:     _nextGroup,
            onPrev:     _prevGroup,
            onViewed:   widget.onViewed,
          ),
        );
      },
    );
  }
}

// ── Single group viewer (one user's stories) ─────────────────────────
class _SingleGroupViewer extends StatefulWidget {
  final List<StoryModel> stories;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final void Function(String)? onViewed;

  const _SingleGroupViewer({
    required this.stories,
    required this.onNext,
    required this.onPrev,
    this.onViewed,
  });

  @override
  State<_SingleGroupViewer> createState() => _SingleGroupViewerState();
}

class _SingleGroupViewerState extends State<_SingleGroupViewer>
    with SingleTickerProviderStateMixin {

  late AnimationController _progressCtrl;
  Timer? _timer;
  int    _idx     = 0;
  bool   _paused  = false;
  bool   _liked   = false;

  // Пешнамоиши бинандагон (барои тугмаи «Амалҳо»-и поён)
  List<String> _viewerAvatars = [];
  int          _viewerCount   = 0;

  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  final _replyCtrl    = TextEditingController();
  bool _showReply     = false;
  bool _sendingReply  = false;

  StoryModel get _current => widget.stories[_idx];
  bool get _isVideo  => _current.mediaType == 'video';
  bool get _isOwner {
    final myId = (UserSession.userId ?? '').trim();
    final sid  = _current.user.id.trim();
    if (myId.isNotEmpty && sid.isNotEmpty && myId == sid) return true;
    final myName = (UserSession.username ?? '').trim().toLowerCase();
    final sName  = _current.user.username.trim().toLowerCase();
    return myName.isNotEmpty && sName.isNotEmpty && myName == sName;
  }

  static const List<String> _emojis = ['❤️', '🔥', '😍', '😂', '😮', '😢', '👏', '🙏'];
  static const Duration _imageDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this);
    _loadStory();
    _markViewed();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _timer?.cancel();
    _videoCtrl?.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  void _loadStory() {
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _videoReady = false;
    _liked = _current.isLiked;

    if (_isVideo) {
      _initVideo();
    } else {
      _startProgress(_imageDuration);
    }
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(_current.mediaUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl!.play();
        final dur = _videoCtrl!.value.duration;
        _startProgress(dur.inSeconds > 0 ? dur : const Duration(seconds: 15));
      });
  }

  void _startProgress(Duration dur) {
    _progressCtrl.duration = dur;
    _progressCtrl.reset();
    _progressCtrl.forward();
    _timer?.cancel();
    _timer = Timer(dur, _nextStory);
  }

  void _pause() {
    if (_paused) return;
    _progressCtrl.stop();
    _timer?.cancel();
    _videoCtrl?.pause();
    setState(() => _paused = true);
  }

  /// Ба профили муаллифи сторис мегузарад (зеркунии аватар ё username).
  void _openAuthorProfile() {
    final uid = _current.user.id.trim();
    if (uid.isEmpty) return;
    _pause();
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/profile', arguments: uid);
  }

  void _resume() {
    if (!_paused) return;
    final remaining = _progressCtrl.duration! * (1 - _progressCtrl.value);
    _progressCtrl.forward();
    _timer = Timer(remaining, _nextStory);
    _videoCtrl?.play();
    setState(() => _paused = false);
  }

  void _nextStory() {
    if (_idx < widget.stories.length - 1) {
      setState(() { _idx++; _paused = false; });
      _loadStory();
      _markViewed();
    } else {
      widget.onNext();
    }
  }

  void _prevStory() {
    if (_idx > 0) {
      setState(() { _idx--; _paused = false; });
      _loadStory();
    } else {
      widget.onPrev();
    }
  }

  Future<void> _markViewed() async {
    widget.onViewed?.call(_current.id);
    AnalyticsService.instance.logEvent(AnalyticsEvents.storyView,
        params: {'storyId': _current.id});
    try {
      await ApiClient.instance.post('/stories/${_current.id}/view');
    } catch (_) {}
    if (_isOwner) _loadViewerPreview();
  }

  // Пешнамоиши бинандагон (то 3 аватар + шумора) барои тугмаи «Амалҳо».
  Future<void> _loadViewerPreview() async {
    setState(() { _viewerAvatars = []; _viewerCount = 0; });
    try {
      final res = await ApiClient.instance.get('/stories/${_current.id}/viewers');
      if (res.statusCode >= 400 || !mounted) return;
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      final viewers = (b['viewers'] as List?) ?? [];
      setState(() {
        _viewerCount = (b['viewsCount'] as num?)?.toInt() ?? viewers.length;
        _viewerAvatars = viewers
            .take(3)
            .map((v) => (v['avatar'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      });
    } catch (_) {}
  }

  // ── Owner menu — ТОҶИКӢ ─────────────────────────────────────────
  void _showOwnerMenu() {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        // Менюи матнӣ бе icon — айнан мисли Instagram
        _menuRow(tr('story.delete'), red: true,
            onTap: () { Navigator.pop(context); _deleteStory(); }),
        _menuRow(tr('story.archive'), onTap: () async {
            Navigator.pop(context);
            try {
              await ApiClient.instance.post('/stories/${_current.id}/archive');
              _toast(tr('story.archivedSuccess'));
            } catch (_) { _toast(tr('common.error')); }
            _resume();
          }),
        _menuRow(_isVideo ? tr('story.saveVideo') : tr('story.saveImage'),
            onTap: () { Navigator.pop(context); _resume(); _saveMedia(); }),
        _menuRow(tr('story.shareAction'),
            onTap: () { Navigator.pop(context); _shareStory(); }),
        _menuRow(tr('story.settings'), onTap: () async {
            Navigator.pop(context);
            try {
              final res = await ApiClient.instance
                  .post('/stories/${_current.id}/toggle-replies');
              if (res.statusCode >= 400) throw Exception();
              final b = jsonDecode(res.body) as Map<String, dynamic>;
              _toast(b['repliesOff'] == true
                  ? tr('story.repliesOff')
                  : tr('story.repliesOn'));
            } catch (_) { _toast(tr('common.error')); }
            if (mounted) _resume();
          }),
        _menuRow(tr('story.disableComments'), onTap: () async {
            Navigator.pop(context);
            try {
              await ApiClient.instance.post('/stories/${_current.id}/toggle-replies');
              _toast(tr('story.repliesUpdated'));
            } catch (_) { _toast(tr('common.error')); }
            _resume();
          }),
        const SizedBox(height: 8),
      ])),
    ).then((_) => _resume());
  }

  // Сатри менюи матнӣ (бе icon) — мисли Instagram
  Widget _menuRow(String label, {required VoidCallback onTap, bool red = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label,
              style: TextStyle(
                  color: red ? const Color(0xFFFF3B30) : Colors.white,
                  fontSize: 16,
                  fontWeight: red ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }

  Future<void> _deleteStory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Нест кардан?', style: TextStyle(color: Colors.white)),
        content: const Text('Сторис тамоман нест мешавад.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Нест кун', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) { _resume(); return; }
    await ApiClient.instance.delete('/stories/${_current.id}');
    if (mounted) widget.onNext();
  }

  void _shareStory() {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(tr('common.share'),
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          // Ба чат фиристодан — корти пешнамоиш, мисли Instagram.
          ShareToChatRow(
            kind: 'story',
            contentId: _current.id,
            shareUrl: _current.mediaUrl,
            thumbUrl: _current.mediaUrl,
            authorUsername: _current.user.username,
          ),
          Divider(color: AppColors.dividerFaint, height: 1),
          ListTile(
            leading: Icon(AppIcons.share_rounded, color: AppColors.textPrimary),
            title: Text('Барномаҳои дигар',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(sheetCtx);
              Share.share('Raonson Story: ${_current.mediaUrl}');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ).whenComplete(() { if (mounted) _resume(); });
  }

  Future<void> _reportStory() async {
    _pause();
    final result = await ReportDialog.showWithDescription(context);
    if (result == null) { _resume(); return; }
    try {
      await ApiClient.instance.post(
        '/stories/${_current.id}/report',
        body: {'reason': result.reason, 'description': result.description});
    } catch (_) {}
    if (mounted) _toast('Шикоят фиристода шуд');
    _resume();
  }

  void _saveMedia() {
    final u = _current.mediaUrl;
    if (u.isNotEmpty) {
      launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _toggleLike() {
    setState(() => _liked = !_liked);
    ApiClient.instance.post('/stories/${_current.id}/like').then((_) {}).catchError((e) => e);
    if (_liked) {
      AnalyticsService.instance.logEvent(AnalyticsEvents.storyLike,
          params: {'storyId': _current.id});
      _showHeartAnim();
    }
  }

  void _showHeartAnim() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _HeartOverlay(onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  // Сторисро ба «Актуальный» (highlights) илова мекунад.
  Future<void> _addToHighlight() async {
    _pause();
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Актуальни нав', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 16,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ном (масалан, Сафар)',
            hintStyle: TextStyle(color: Colors.white38),
            counterStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Илова', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) { _resume(); return; }
    try {
      await ApiClient.instance.post('/highlights/', body: {
        'title': name,
        'coverUrl': _current.mediaUrl,
        'storyIds': [_current.id],
        'items': [
          {'url': _current.mediaUrl, 'type': _current.mediaType, 'storyId': _current.id}
        ],
      });
      _toast('Ба «$name» илова шуд ✓');
    } catch (_) { _toast('Хато'); }
    _resume();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      await ApiClient.instance.post('/stories/${_current.id}/reply', body: {'text': text});
      _replyCtrl.clear();
      if (mounted) { setState(() { _showReply = false; _sendingReply = false; }); _resume(); }
    } catch (_) {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  void _sendEmoji(String emoji) {
    _resume();
    ApiClient.instance.post('/stories/${_current.id}/reply', body: {'text': emoji}).then((_) {}).catchError((e) => e);
    _showFloatingEmoji(emoji);
  }

  void _showFloatingEmoji(String emoji) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _FloatingEmoji(emoji: emoji, onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        onTapUp: (d) {
          if (_showReply) return;
          final x = d.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if (x < w * 0.33) { _prevStory(); }
          else if (x > w * 0.67) { _nextStory(); }
          else { _paused ? _resume() : _pause(); }
        },
        // Instagram-монанд: боло кашидан → статистика/ҷавоб, поён → пӯшидан
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) {
            if (_isOwner) {
              _showViewersSheet();
            } else if (!_current.repliesOff) {
              _pause();
              setState(() => _showReply = true);
            }
          } else if (v > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          // ── Media ──────────────────────────────────────────────
          _isVideo ? _buildVideo() : _buildImage(),

          // ── Top gradient ───────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0, height: 160,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),

          // ── Bottom gradient ────────────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0, height: 220,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.85), Colors.transparent])))),

          // ── Multi-segment progress bars ────────────────────────
          Positioned(
            top: top + 6, left: 8, right: 8,
            child: Row(children: List.generate(widget.stories.length, (i) {
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: i < widget.stories.length - 1 ? 3 : 0),
                child: i < _idx
                    ? _ProgressBar(value: 1.0)
                    : i == _idx
                        ? (_isVideo && !_videoReady)
                            ? _ProgressBar(value: 0)
                            : AnimatedBuilder(
                                animation: _progressCtrl,
                                builder: (_, __) => _ProgressBar(value: _progressCtrl.value))
                        : _ProgressBar(value: 0.0),
              ));
            })),
          ),

          // ── Header ─────────────────────────────────────────────
          Positioned(
            top: top + 18, left: 12, right: 12,
            child: Row(children: [
              GestureDetector(
                onTap: _openAuthorProfile,
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: _current.user.avatar.isNotEmpty
                      ? CachedNetworkImageProvider(_current.user.avatar, maxWidth: 80) : null,
                  backgroundColor: Colors.white12,
                  child: _current.user.avatar.isEmpty
                      ? const Icon(AppIcons.person, color: Colors.white54, size: 20) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: _openAuthorProfile,
                behavior: HitTestBehavior.opaque,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(_current.user.username,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black54)]))),
                  if (_current.user.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(AppIcons.verified_rounded,
                        fill: 1, color: Colors.white, size: 14),
                  ],
                  if (_current.audience == 'close') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('Наздикон',
                          style: TextStyle(color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                Text(_timeAgo(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]))),
              if (_isOwner)
                GestureDetector(
                  onTap: _showOwnerMenu,
                  child: const Padding(padding: EdgeInsets.all(6),
                    child: Icon(AppIcons.more_vert, color: Colors.white, size: 24))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(padding: EdgeInsets.all(6),
                  child: Icon(AppIcons.close, color: Colors.white, size: 24))),
            ]),
          ),

          // ── Caption ────────────────────────────────────────────
          // if ((_current.caption ?? '').isNotEmpty)   (StoryModel has no caption field yet)
          // Positioned(bottom: 130, left: 16, right: 16,
          //   child: Text(_current.caption!, style: TextStyle(color: Colors.white, fontSize: 15))),

          // ── Bottom actions ─────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 8, right: 8,
            child: _showReply ? _buildReplyInput() : _buildActions(),
          ),
        ]),
      ),
    );
  }

  void _showViewersSheet() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StoryInsightsSheet(storyId: _current.id),
    ).whenComplete(_resume);
  }


  Widget _buildActions() {
    if (_isOwner) {
      // Айнан мисли Instagram: чап — «Амалҳо» бо аватарҳои бинандагон,
      // баъд Мубодила / Актуалӣ / Зикр / Бештар.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ActivityBtn(
            avatars: _viewerAvatars,
            count: _viewerCount,
            onTap: _showViewersSheet,
          ),
          const Spacer(),
          _ActionBtn(svgPath: 'assets/icons/share.svg', label: 'Мубодила',
              onTap: _shareStory),
          const SizedBox(width: 4),
          _ActionBtn(icon: AppIcons.add_box_outlined, label: 'Актуалӣ',
              onTap: _addToHighlight),
          const SizedBox(width: 4),
          _ActionBtn(icon: AppIcons.more_horiz_rounded, label: 'Бештар',
              onTap: _showOwnerMenu),
        ],
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!_current.repliesOff) ...[
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
          children: _emojis.map((e) => GestureDetector(
            onTap: () => _sendEmoji(e),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white12,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(e, style: const TextStyle(fontSize: 22))),
          )).toList())),
        const SizedBox(height: 10),
      ],
      Row(children: [
        Expanded(child: _current.repliesOff
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.centerLeft,
              child: const Text('Ҷавобҳо хомӯшанд',
                  style: TextStyle(color: Colors.white54, fontSize: 13)))
          : GestureDetector(
              onTap: () { _pause(); setState(() => _showReply = true); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38, width: 1.5),
                  borderRadius: BorderRadius.circular(24)),
                child: Text('${_current.user.username}-га ҷавоб...',
                    style: const TextStyle(color: Colors.white70, fontSize: 14))),
            )),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _toggleLike,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _liked ? AppIcons.favorite : AppIcons.favorite_border,
              key: ValueKey(_liked),
              color: _liked ? Colors.red : Colors.white, size: 28))),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _shareStory,
          child: const Icon(AppIcons.send_outlined, color: Colors.white, size: 26)),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _reportStory,
          child: const Icon(AppIcons.flag_outlined, color: Colors.white54, size: 24)),
      ]),
    ]);
  }

  Widget _buildReplyInput() {
    return Row(children: [
      Expanded(child: TextField(
        controller: _replyCtrl, autofocus: true,
        style: const TextStyle(color: Colors.white),
        onSubmitted: (_) => _sendReply(),
        decoration: InputDecoration(
          hintText: '${_current.user.username}-га ҷавоб...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true, fillColor: Colors.white12,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _sendingReply
              ? const Padding(padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: const Icon(AppIcons.send_rounded, color: AppColors.neonBlue),
                  onPressed: _sendReply)),
      )),
      IconButton(
        icon: const Icon(AppIcons.close, color: Colors.white54),
        onPressed: () { setState(() => _showReply = false); _resume(); }),
    ]);
  }

  Widget _buildImage() {
    if (_current.mediaUrl.isEmpty) return Container(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: _current.mediaUrl, fit: BoxFit.cover,
      memCacheWidth: 1080,
      width: double.infinity, height: double.infinity,
      placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)),
      errorWidget: (_, __, ___) => const Center(
          child: Icon(AppIcons.broken_image_outlined, color: Colors.white38, size: 64)));
  }

  Widget _buildVideo() {
    if (!_videoReady) { return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)); }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width:  _videoCtrl!.value.size.width,
        height: _videoCtrl!.value.size.height,
        child:  VideoPlayer(_videoCtrl!)));
  }

  String _timeAgo() {
    final created = _current.expiresAt.subtract(const Duration(hours: 24));
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1)  return 'ҳозир';
    if (diff.inMinutes < 60) return '${diff.inMinutes} дақ';
    if (diff.inHours   < 24) return '${diff.inHours} соат';
    return '${diff.inDays} рӯз';
  }
}

// ── Progress bar ─────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: value,
      backgroundColor: Colors.white30,
      valueColor: const AlwaysStoppedAnimation(Colors.white),
      minHeight: 2.5));
}

// ── Action button for owner (plain icon + label, мисли Instagram) ──────
class _ActionBtn extends StatelessWidget {
  final IconData? icon;
  final String? svgPath;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionBtn({this.icon, this.svgPath, required this.label,
      required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 64,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        svgPath != null
          ? SvgPicture.asset(svgPath!, width: 26, height: 26,
              colorFilter: ColorFilter.mode(color ?? Colors.white, BlendMode.srcIn))
          : Icon(icon, color: color ?? Colors.white, size: 27),
        const SizedBox(height: 5),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color ?? Colors.white, fontSize: 11)),
      ]),
    ));
}

// ── «Амалҳо» — аватарҳои бинандагон + шумора (мисли Instagram) ─────────
class _ActivityBtn extends StatelessWidget {
  final List<String> avatars;
  final int count;
  final VoidCallback onTap;
  const _ActivityBtn({required this.avatars, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (avatars.isEmpty)
          const Icon(AppIcons.favorite_border_rounded, color: Colors.white, size: 27)
        else
          SizedBox(
            height: 30,
            width: (avatars.length * 18.0) + 12,
            child: Stack(
              children: List.generate(avatars.length, (i) => Positioned(
                left: i * 18.0,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                        imageUrl: avatars[i], fit: BoxFit.cover,
                        memCacheWidth: 60,
                        errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF333333),
                            child: const Icon(AppIcons.person,
                                color: Colors.white54, size: 16))),
                  ),
                ),
              )),
            ),
          ),
        const SizedBox(height: 5),
        Text(count > 0 ? 'Амалҳо · $count' : 'Амалҳо',
            maxLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }
}

// ── Heart overlay ────────────────────────────────────────────────────
class _HeartOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _HeartOverlay({required this.onDone});
  @override
  State<_HeartOverlay> createState() => _HeartOverlayState();
}

// Instagram-монанд: чанд дил аз гӯшаи поёни чап боло парвоз мекунад.
class _HeartOverlayState extends State<_HeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rnd = math.Random();
  late final List<_HeartParticle> _hearts;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))..forward();
    _hearts = List.generate(7, (i) {
      return _HeartParticle(
        startDelay: i * 0.06,
        driftX: (_rnd.nextDouble() * 70) + 10,   // ба рост каҷ мешавад
        wobble: (_rnd.nextDouble() * 26) + 8,
        rise: (_rnd.nextDouble() * 120) + 280,   // баландии парвоз
        size: (_rnd.nextDouble() * 14) + 22,
        color: [
          const Color(0xFFFF3040),
          const Color(0xFFFF6B9D),
          const Color(0xFFE91E63),
          Colors.white,
        ][i % 4],
      );
    });
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 80;
    return Positioned(
      left: 18, bottom: bottom,
      child: SizedBox(
        width: 140, height: 440,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Stack(
            clipBehavior: Clip.none,
            children: _hearts.map((h) {
              final t = ((_ctrl.value - h.startDelay) / (1 - h.startDelay))
                  .clamp(0.0, 1.0);
              if (t <= 0) return const SizedBox.shrink();
              final y = -h.rise * Curves.easeOut.transform(t);
              final x = h.driftX * t +
                  math.sin(t * math.pi * 3) * h.wobble;
              final opacity = t < 0.15
                  ? (t / 0.15)
                  : (1.0 - ((t - 0.15) / 0.85)).clamp(0.0, 1.0);
              final scale = (0.4 + t * 0.9).clamp(0.4, 1.3);
              return Positioned(
                left: x, bottom: -y,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Icon(AppIcons.favorite, color: h.color, size: h.size,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black45)
                        ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _HeartParticle {
  final double startDelay, driftX, wobble, rise, size;
  final Color color;
  const _HeartParticle({
    required this.startDelay, required this.driftX, required this.wobble,
    required this.rise, required this.size, required this.color,
  });
}

// ── Floating emoji ───────────────────────────────────────────────────
class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onDone;
  const _FloatingEmoji({required this.emoji, required this.onDone});
  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _y, _opacity, _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _y       = Tween(begin: 0.0, end: -200.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _scale   = Tween(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.3, curve: Curves.elasticOut)));
    _ctrl.addStatusListener((s) { if (s == AnimationStatus.completed) widget.onDone(); });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 120, left: 0, right: 0,
    child: AnimatedBuilder(animation: _ctrl,
      builder: (_, __) => Transform.translate(offset: Offset(0, _y.value),
        child: Opacity(opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value,
            child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 48))))))));
}

// ─────────────────────────────────────────────────────────────────
// Story insights / "seen by" sheet — мисли Instagram.
// Худаш маълумотро бор мекунад, то ҳамеша дуруст навсозӣ шавад.
// ─────────────────────────────────────────────────────────────────
class StoryInsightsSheet extends StatefulWidget {
  final String storyId;
  const StoryInsightsSheet({super.key, required this.storyId});

  @override
  State<StoryInsightsSheet> createState() => _StoryInsightsSheetState();
}

class _StoryInsightsSheetState extends State<StoryInsightsSheet> {
  bool _loading = true;
  int _views = 0, _likes = 0, _replies = 0, _interactions = 0;
  int _folViewed = 0, _folTotal = 0, _nonFol = 0;
  List<Map<String, dynamic>> _viewers = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final resp =
          await ApiClient.instance.get('/stories/${widget.storyId}/viewers');
      if (!mounted) return;
      if (resp.statusCode >= 400) {
        setState(() => _loading = false);
        return;
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['viewers'] as List? ?? [])
          .map((v) => v as Map<String, dynamic>)
          .toList();
      setState(() {
        _viewers = list;
        _views = (body['viewsCount'] as num?)?.toInt() ?? list.length;
        _likes = (body['likesCount'] as num?)?.toInt() ?? 0;
        _replies = (body['repliesCount'] as num?)?.toInt() ?? 0;
        _interactions = (body['interactions'] as num?)?.toInt() ??
            (_likes + _replies);
        _folViewed = (body['followersViewed'] as num?)?.toInt() ?? 0;
        _folTotal  = (body['followersTotal']  as num?)?.toInt() ?? 0;
        _nonFol    = (body['nonFollowers']     as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      maxChildSize: 0.95,
      minChildSize: 0.35,
      expand: false,
      builder: (_, scrollCtrl) => Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),

        // ── Обзор / Insights ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: [
            Expanded(child: _stat(AppIcons.remove_red_eye_outlined, '$_views', 'Бинандагон')),
            _divider(),
            Expanded(child: _stat(AppIcons.bolt_rounded, '$_interactions', 'Ҳамкориҳо')),
            _divider(),
            Expanded(child: _stat(AppIcons.favorite, '$_likes', 'Лайкҳо', color: Colors.red)),
            _divider(),
            Expanded(child: _stat(AppIcons.chat_bubble_outline_rounded, '$_replies', 'Ҷавобҳо')),
          ]),
        ),
        // ── Омори пайравон ──
        if (!_loading && _views > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(AppIcons.group_rounded, color: Colors.white54, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_folViewed аз ${_folTotal == 0 ? _folViewed : _folTotal} пайрав дид'
                  '${_nonFol > 0 ? '  ·  $_nonFol ғайри пайрав' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ]),
          ),
        const Divider(color: Colors.white12, height: 1),

        if (!_loading && _viewers.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Кӣ сторисро дид',
                  style: TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),

        // ── Seen-by list (мисли Instagram) ──
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white30, strokeWidth: 2))
              : _viewers.isEmpty
                  ? const Center(
                      child: Text('Ҳанӯз касе надидааст',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.only(top: 2, bottom: 16),
                      itemCount: _viewers.length,
                      itemBuilder: (_, i) {
                        final v = _viewers[i];
                        final avatar = (v['avatar'] ?? '').toString();
                        final uname = (v['username'] ?? '').toString();
                        final name = (v['fullName'] ?? '').toString();
                        final liked = v['liked'] == true;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          child: Row(children: [
                            // Аватар + нишони дил (агар лайк карда бошад)
                            Stack(clipBehavior: Clip.none, children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white12,
                                backgroundImage: avatar.isNotEmpty
                                    ? CachedNetworkImageProvider(avatar) : null,
                                child: avatar.isEmpty
                                    ? Text(uname.isNotEmpty
                                        ? uname[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white))
                                    : null,
                              ),
                              if (liked)
                                Positioned(
                                  bottom: -2, right: -2,
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF2D55),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF1A1A1A), width: 2),
                                    ),
                                    child: const Icon(AppIcons.favorite,
                                        color: Colors.white, size: 11),
                                  ),
                                ),
                            ]),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(uname,
                                      style: const TextStyle(color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600)),
                                  if (name.isNotEmpty)
                                    Text(name, maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 12.5)),
                                ],
                              ),
                            ),
                            const Icon(AppIcons.more_vert,
                                color: Colors.white54, size: 20),
                            const SizedBox(width: 14),
                            SvgPicture.asset('assets/icons/share.svg',
                                width: 22, height: 22,
                                colorFilter: const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn)),
                          ]),
                        );
                      }),
        ),
      ]),
    );
  }

  Widget _stat(IconData icon, String value, String label, {Color? color}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color ?? Colors.white70, size: 20),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }

  Widget _divider() => Container(
      width: 1, height: 34, color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}
