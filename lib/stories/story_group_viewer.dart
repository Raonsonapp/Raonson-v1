// lib/stories/story_group_viewer.dart
// Multi-story group viewer — мисли Instagram
// Groups = List<List<StoryModel>>, navigate between users with swipe

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/story_model.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../app/app_theme.dart';

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

  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  final _replyCtrl    = TextEditingController();
  bool _showReply     = false;
  bool _sendingReply  = false;

  StoryModel get _current => widget.stories[_idx];
  bool get _isVideo  => _current.mediaType == 'video';
  bool get _isOwner  => UserSession.userId == _current.user.id;

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
    try {
      await ApiClient.instance.post('/stories/${_current.id}/view');
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
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Нест кун',
              style: TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.w500)),
          onTap: () { Navigator.pop(context); _deleteStory(); }),
        ListTile(
          leading: const Icon(Icons.archive_outlined, color: Colors.white),
          title: const Text('Бойгонӣ', style: TextStyle(color: Colors.white, fontSize: 17)),
          onTap: () { Navigator.pop(context); _resume(); _toast('Бойгонӣ ба зудӣ илова мешавад'); }),
        ListTile(
          leading: Icon(_isVideo ? Icons.video_collection_outlined : Icons.save_alt_outlined,
              color: Colors.white),
          title: Text(_isVideo ? 'Видео ҳифз кун' : 'Расм ҳифз кун',
              style: const TextStyle(color: Colors.white, fontSize: 17)),
          onTap: () { Navigator.pop(context); _resume(); _saveMedia(); }),
        ListTile(
          leading: const Icon(Icons.share_outlined, color: Colors.white),
          title: const Text('Мубодила кун', style: TextStyle(color: Colors.white, fontSize: 17)),
          onTap: () { Navigator.pop(context); _shareStory(); }),
        ListTile(
          leading: const Icon(Icons.comment_bank_outlined, color: Colors.white),
          title: const Text('Шарҳро хомӯш кун',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          onTap: () { Navigator.pop(context); _resume(); _toast('Ин хосият ба зудӣ илова мешавад'); }),
        const SizedBox(height: 8),
      ])),
    ).then((_) => _resume());
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
    Share.share('Raonson Story: ${_current.mediaUrl}');
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
    if (_liked) _showHeartAnim();
  }

  void _showHeartAnim() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _HeartOverlay(onDone: () => entry.remove()));
    overlay.insert(entry);
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
            } else {
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
              CircleAvatar(
                radius: 20,
                backgroundImage: _current.user.avatar.isNotEmpty
                    ? NetworkImage(_current.user.avatar) : null,
                backgroundColor: Colors.white12,
                child: _current.user.avatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_current.user.username,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                Text(_timeAgo(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              if (_isOwner)
                GestureDetector(
                  onTap: _showOwnerMenu,
                  child: const Padding(padding: EdgeInsets.all(6),
                    child: Icon(Icons.more_vert, color: Colors.white, size: 24))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 24))),
            ]),
          ),

          // ── Caption ────────────────────────────────────────────
          // if ((_current.caption ?? '').isNotEmpty)   (StoryModel has no caption field yet)
          // Positioned(bottom: 130, left: 16, right: 16,
          //   child: Text(_current.caption!, style: TextStyle(color: Colors.white, fontSize: 15))),

          // ── Owner: viewers hint ────────────────────────────────
          if (_isOwner)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 90,
              left: 0, right: 0,
              child: GestureDetector(
                onTap: _showViewersSheet,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('${_current.viewsCount} кас дид',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('${_current.likesCount}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ]))),

          // ── Bottom actions ─────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 12, right: 12,
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
      return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _ActionBtn(svgPath: 'assets/icons/share.svg', label: 'Мубодила', onTap: _shareStory),
        _ActionBtn(icon: Icons.delete_outline, label: 'Нест кун',
            onTap: _deleteStory, color: Colors.redAccent),
        _ActionBtn(icon: Icons.more_horiz_rounded, label: 'Бештар', onTap: _showOwnerMenu),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
      Row(children: [
        Expanded(child: GestureDetector(
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
              _liked ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(_liked),
              color: _liked ? Colors.red : Colors.white, size: 28))),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: _shareStory,
          child: const Icon(Icons.send_outlined, color: Colors.white, size: 26)),
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
                  icon: const Icon(Icons.send_rounded, color: AppColors.neonBlue),
                  onPressed: _sendReply)),
      )),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white54),
        onPressed: () { setState(() => _showReply = false); _resume(); }),
    ]);
  }

  Widget _buildImage() {
    if (_current.mediaUrl.isEmpty) return Container(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: _current.mediaUrl, fit: BoxFit.cover,
      width: double.infinity, height: double.infinity,
      placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)),
      errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64)));
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

// ── Action button for owner ──────────────────────────────────────────
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
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 48, height: 48,
        decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
        child: Center(child: svgPath != null
          ? SvgPicture.asset(svgPath!, width: 22, height: 22,
              colorFilter: ColorFilter.mode(color ?? Colors.white, BlendMode.srcIn))
          : Icon(icon, color: color ?? Colors.white, size: 22))),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color ?? Colors.white70, fontSize: 10)),
    ]));
}

// ── Heart overlay ────────────────────────────────────────────────────
class _HeartOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _HeartOverlay({required this.onDone});
  @override
  State<_HeartOverlay> createState() => _HeartOverlayState();
}

class _HeartOverlayState extends State<_HeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _scale   = Tween(begin: 0.5, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));
    _ctrl.addStatusListener((s) { if (s == AnimationStatus.completed) widget.onDone(); });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: AnimatedBuilder(animation: _ctrl,
    builder: (_, __) => Opacity(opacity: _opacity.value,
      child: Transform.scale(scale: _scale.value,
        child: const Icon(Icons.favorite, color: Colors.white, size: 100,
            shadows: [Shadow(blurRadius: 20, color: Colors.black54)])))));
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
            Expanded(child: _stat(Icons.remove_red_eye_outlined, '$_views', 'Бинандагон')),
            _divider(),
            Expanded(child: _stat(Icons.bolt_rounded, '$_interactions', 'Ҳамкориҳо')),
            _divider(),
            Expanded(child: _stat(Icons.favorite, '$_likes', 'Лайкҳо', color: Colors.red)),
            _divider(),
            Expanded(child: _stat(Icons.chat_bubble_outline_rounded, '$_replies', 'Ҷавобҳо')),
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
              const Icon(Icons.group_rounded, color: Colors.white54, size: 18),
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

        // ── Seen-by list ──
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
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      itemCount: _viewers.length,
                      itemBuilder: (_, i) {
                        final v = _viewers[i];
                        final avatar = (v['avatar'] ?? '').toString();
                        final uname = (v['username'] ?? '').toString();
                        final name = (v['fullName'] ?? '').toString();
                        final liked = v['liked'] == true;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white12,
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? Text(
                                    uname.isNotEmpty
                                        ? uname[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white))
                                : null,
                          ),
                          title: Text(uname,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                          subtitle: name.isEmpty
                              ? null
                              : Text(name,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                          trailing: liked
                              ? const Icon(Icons.favorite,
                                  color: Colors.red, size: 18)
                              : null,
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
