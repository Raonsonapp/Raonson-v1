import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../models/story_model.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../app/app_theme.dart';

class StoryViewer extends StatefulWidget {
  final StoryModel story;
  final VoidCallback onComplete;

  const StoryViewer({
    super.key,
    required this.story,
    required this.onComplete,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  Timer? _timer;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _paused     = false;

  final _replyCtrl   = TextEditingController();
  bool _showReply    = false;
  bool _sendingReply = false;
  bool _liked        = false;

  int  _viewsCount = 0;
  int  _likesCount = 0;
  List _viewers    = [];
  List _replies    = [];

  bool get _isVideo => widget.story.mediaType == 'video';

  bool get _isOwner {
    final myId = UserSession.userId?.trim() ?? '';
    return myId.isNotEmpty && myId == widget.story.user.id.trim();
  }

  // ── Emoji reactions мисли Instagram ─────────────────────────────
  static const List<String> _emojis = ['❤️', '🔥', '😍', '😂', '😮', '😢', '👏', '🙏'];

  @override
  void initState() {
    super.initState();
    _viewsCount = widget.story.viewsCount;
    _likesCount = widget.story.likesCount;
    _liked      = widget.story.isLiked;

    if (_isVideo) {
      _initVideo();
    } else {
      _startProgress(const Duration(seconds: 5));
    }
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      await ApiClient.instance.post('/stories/${widget.story.id}/view');
    } catch (_) {}
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.story.mediaUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl!.play();
        final dur = _videoCtrl!.value.duration;
        _startProgress(dur.inSeconds > 0 ? dur : const Duration(seconds: 15));
      });
  }

  void _startProgress(Duration duration) {
    _progressCtrl = AnimationController(vsync: this, duration: duration)
      ..forward();
    _timer = Timer(duration, _close);
  }

  void _pause() {
    if (!_progressCtrl.isAnimating) return;
    _progressCtrl.stop();
    _timer?.cancel();
    _videoCtrl?.pause();
    setState(() => _paused = true);
  }

  void _resume() {
    if (_paused == false) return;
    _progressCtrl.forward();
    final remaining = _progressCtrl.duration! * (1 - _progressCtrl.value);
    _timer = Timer(remaining, _close);
    _videoCtrl?.play();
    setState(() => _paused = false);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
    widget.onComplete();
  }

  // ── OWNER: ⋮ меню мисли Instagram (расм 1) ──────────────────────
  void _showOwnerMenu() {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          // Удалить
          ListTile(
            title: const Text('Удалить',
                style: TextStyle(color: Colors.redAccent,
                    fontSize: 17, fontWeight: FontWeight.w500)),
            onTap: () { Navigator.pop(context); _deleteStory(); },
          ),
          // Архивировать
          ListTile(
            title: const Text('Архивировать',
                style: TextStyle(color: Colors.white, fontSize: 17)),
            onTap: () { Navigator.pop(context); _resume(); },
          ),
          // Сохранить видео/фото
          ListTile(
            title: Text(_isVideo ? 'Сохранить видео' : 'Сохранить фото',
                style: const TextStyle(color: Colors.white, fontSize: 17)),
            onTap: () { Navigator.pop(context); _resume(); },
          ),
          // Отправить
          ListTile(
            title: const Text('Отправить...',
                style: TextStyle(color: Colors.white, fontSize: 17)),
            onTap: () { Navigator.pop(context); _shareStory(); },
          ),
          // Поделиться
          ListTile(
            title: const Text('Поделиться',
                style: TextStyle(color: Colors.white, fontSize: 17)),
            onTap: () { Navigator.pop(context); _shareStory(); },
          ),
          // Выключить комментарии
          ListTile(
            title: const Text('Выключить комментарии',
                style: TextStyle(color: Colors.white, fontSize: 17)),
            onTap: () { Navigator.pop(context); _resume(); },
          ),
          const SizedBox(height: 8),
        ],
      )),
    ).then((_) => _resume());
  }

  Future<void> _deleteStory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Ҳазф кардан?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Story тамоман ҳазф мешавад.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор',
                  style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Ҳазф',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) { _resume(); return; }
    await ApiClient.instance.delete('/stories/${widget.story.id}');
    if (mounted) _close();
  }

  void _shareStory() {
    Share.share('Raonson Story: ${widget.story.mediaUrl}');
    _resume();
  }

  // ── OWNER: Viewers Panel мисли Instagram (расм 3) ────────────────
  Future<void> _showViewersPanel() async {
    _pause();
    try {
      final res = await ApiClient.instance
          .get('/stories/${widget.story.id}/viewers');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _viewsCount = data['viewsCount'] ?? _viewsCount;
          _likesCount = data['likesCount'] ?? _likesCount;
          _viewers    = data['viewers']    ?? [];
          _replies    = data['replies']    ?? [];
        });
      }
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OwnerViewersSheet(
        story:      widget.story,
        viewsCount: _viewsCount,
        likesCount: _likesCount,
        viewers:    _viewers,
        replies:    _replies,
        onDelete:   () { Navigator.pop(context); _deleteStory(); },
      ),
    ).then((_) => _resume());
  }

  // ── OTHER USER: like toggle ───────────────────────────────────────
  void _toggleLike() async {
    setState(() => _liked = !_liked);
    if (_liked) _showHeartAnim();
    try {
      await ApiClient.instance.post('/stories/${widget.story.id}/like');
    } catch (_) {}
  }

  void _showHeartAnim() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _HeartOverlay(onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  // ── OTHER USER: reply ─────────────────────────────────────────────
  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      await ApiClient.instance.post(
          '/stories/${widget.story.id}/reply',
          body: {'text': text});
      _replyCtrl.clear();
      if (mounted) {
        setState(() { _showReply = false; _sendingReply = false; });
        _resume();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Фиристода шуд ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2)));
      }
    } catch (_) {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  // ── OTHER USER: emoji reaction ────────────────────────────────────
  void _sendEmojiReaction(String emoji) async {
    _resume();
    try {
      await ApiClient.instance.post(
          '/stories/${widget.story.id}/reply',
          body: {'text': emoji});
    } catch (_) {}
    if (mounted) {
      _showFloatingEmoji(emoji);
    }
  }

  void _showFloatingEmoji(String emoji) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _FloatingEmoji(
      emoji: emoji,
      onDone: () => entry.remove(),
    ));
    overlay.insert(entry);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _timer?.cancel();
    _videoCtrl?.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
            if (_isOwner) _showViewersPanel();
          }
        },
        onTapUp: (d) {
          if (_showReply) return;
          final x = d.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if      (x < w * 0.3) { _close(); }
          else if (x > w * 0.7) { _close(); }
          else                   { _paused ? _resume() : _pause(); }
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        child: Stack(fit: StackFit.expand, children: [

          // ── Media ──────────────────────────────────────────────
          _isVideo ? _buildVideo() : _buildImage(),

          // ── Top gradient ───────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0, height: 150,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.65), Colors.transparent],
              ),
            )),
          ),

          // ── Bottom gradient ────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0, height: 200,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
              ),
            )),
          ),

          // ── Progress bar ───────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 8, right: 8,
            child: (_isVideo && !_videoReady)
                ? const SizedBox()
                : AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progressCtrl.value,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 2.5,
                      ),
                    ),
                  ),
          ),

          // ── Header ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 12, right: 12,
            child: Row(children: [
              // Avatar — gradient ring мисли home
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.storyGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.black),
                  padding: const EdgeInsets.all(1.5),
                  child: ClipOval(
                    child: widget.story.userAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.story.userAvatar,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.person, color: Colors.white54, size: 20))
                        : const Icon(Icons.person,
                            color: Colors.white54, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.story.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    )),
                  Text(_timeAgo(), style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
                ],
              )),

              // ⋮ меню — ТАНҲО барои owner
              if (_isOwner)
                GestureDetector(
                  onTap: _showOwnerMenu,
                  child: const Padding(padding: EdgeInsets.all(6),
                    child: Icon(Icons.more_vert,
                        color: Colors.white, size: 24)),
                ),

              const SizedBox(width: 4),
              // ✕ close
              GestureDetector(
                onTap: _close,
                child: const Padding(padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 24)),
              ),
            ]),
          ),

          // ── OWNER: viewers hint (свайп вверх) ─────────────────
          if (_isOwner)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 90,
              left: 0, right: 0,
              child: GestureDetector(
                onTap: _showViewersPanel,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.keyboard_arrow_up,
                      color: Colors.white70, size: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('$_viewsCount кас дид',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    if (_likesCount > 0) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.favorite,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text('$_likesCount',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ]),
                ]),
              ),
            ),

          // ── Bottom actions ─────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 12, right: 12,
            child: _showReply
                ? _buildReplyInput()
                : _isOwner
                    ? _buildOwnerActions()
                    : _buildViewerActions(),
          ),
        ]),
      ),
    );
  }

  // ── OWNER bottom: "История шумо" кнопки мисли расм 2 ────────────
  Widget _buildOwnerActions() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _OwnerActionBtn(
        icon: Icons.share_outlined,
        label: 'Поделиться',
        onTap: _shareStory,
      ),
      _OwnerActionBtn(
        icon: Icons.trending_up_rounded,
        label: 'Продвигать',
        onTap: () {},
      ),
      _OwnerActionBtn(
        icon: Icons.favorite_border_rounded,
        label: 'Добавить',
        onTap: () {},
      ),
      _OwnerActionBtn(
        icon: Icons.alternate_email_rounded,
        label: 'Упомянуть',
        onTap: () {},
      ),
      _OwnerActionBtn(
        icon: Icons.more_horiz_rounded,
        label: 'Ещё',
        onTap: _showOwnerMenu,
      ),
    ]);
  }

  // ── VIEWER bottom: reply + like + comment + share + emojis ───────
  Widget _buildViewerActions() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Emoji реакцияҳо — мисли Instagram
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _emojis.map((e) => GestureDetector(
            onTap: () => _sendEmojiReaction(e),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 10),

      // "Отправить сообщение" + ❤ + 💬 + ↗
      Row(children: [
        // Reply field
        Expanded(
          child: GestureDetector(
            onTap: () { _pause(); setState(() => _showReply = true); },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('Отправить сообщение',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 14)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ❤ Like
        GestureDetector(
          onTap: _toggleLike,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(_liked),
              color: _liked ? Colors.red : Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 💬 Comment
        GestureDetector(
          onTap: () { _pause(); setState(() => _showReply = true); },
          child: const Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),

        // ↗ Share — SVG мисли home
        GestureDetector(
          onTap: () {
            _pause();
            Share.share('Raonson Story: ${widget.story.mediaUrl}');
            _resume();
          },
          child: SvgPicture.asset(
            'assets/icons/share.svg',
            width: 26, height: 26,
            colorFilter: const ColorFilter.mode(
                Colors.white, BlendMode.srcIn),
          ),
        ),
      ]),
    ]);
  }

  // ── Reply input ───────────────────────────────────────────────────
  Widget _buildReplyInput() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _replyCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendReply(),
          decoration: InputDecoration(
            hintText: '${widget.story.username}-га ҷавоб...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            suffixIcon: _sendingReply
                ? const Padding(padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)))
                : IconButton(
                    icon: SvgPicture.asset('assets/icons/share.svg',
                      width: 20, height: 20,
                      colorFilter: const ColorFilter.mode(
                          AppColors.neonBlue, BlendMode.srcIn)),
                    onPressed: _sendReply),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white54),
        onPressed: () {
          setState(() => _showReply = false);
          _resume();
        },
      ),
    ]);
  }

  // ── Media builders ────────────────────────────────────────────────
  Widget _buildImage() {
    if (widget.story.mediaUrl.isEmpty) {
      return Container(color: Colors.grey[900],
        child: const Center(child: Icon(Icons.image_not_supported,
            color: Colors.white30, size: 64)));
    }
    return CachedNetworkImage(
      imageUrl: widget.story.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(color: Colors.black,
        child: const Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white30))),
      errorWidget: (_, __, ___) => Container(color: Colors.grey[900],
        child: const Center(child: Icon(Icons.broken_image,
            color: Colors.white38, size: 72))),
    );
  }

  Widget _buildVideo() {
    if (!_videoReady) {
      return Container(color: Colors.black,
        child: const Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white30)));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width:  _videoCtrl!.value.size.width,
        height: _videoCtrl!.value.size.height,
        child:  VideoPlayer(_videoCtrl!),
      ),
    );
  }

  String _timeAgo() {
    final created = widget.story.expiresAt.subtract(const Duration(hours: 24));
    final diff    = DateTime.now().difference(created);
    if (diff.inMinutes < 1)  return 'ҳозир';
    if (diff.inMinutes < 60) return '${diff.inMinutes} дақ';
    if (diff.inHours   < 24) return '${diff.inHours} соат';
    return '${diff.inDays} рӯз';
  }
}

// ── Owner Action Button (расм 2) ────────────────────────────────────
class _OwnerActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _OwnerActionBtn({required this.icon, required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
            color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

// ── Heart animation overlay ─────────────────────────────────────────
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
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800))..forward();
    _scale   = Tween(begin: 0.5, end: 1.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(animation: _ctrl,
      builder: (_, __) => Opacity(opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value,
          child: const Icon(Icons.favorite,
              color: Colors.white, size: 100,
              shadows: [Shadow(blurRadius: 20, color: Colors.black54)])))));
}

// ── Floating emoji animation ────────────────────────────────────────
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
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..forward();
    _y       = Tween(begin: 0.0, end: -200.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.5, 1.0)));
    _scale   = Tween(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.0, 0.3, curve: Curves.elasticOut)));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120, left: 0, right: 0,
      child: AnimatedBuilder(animation: _ctrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _y.value),
          child: Opacity(opacity: _opacity.value,
            child: Transform.scale(scale: _scale.value,
              child: Center(child: Text(widget.emoji,
                  style: const TextStyle(fontSize: 48))))))));
  }
}

// ══════════════════════════════════════════════════════════════════════
// OWNER VIEWERS SHEET — мисли Instagram (расм 3)
// ══════════════════════════════════════════════════════════════════════
class _OwnerViewersSheet extends StatefulWidget {
  final StoryModel story;
  final int viewsCount, likesCount;
  final List viewers, replies;
  final VoidCallback onDelete;

  const _OwnerViewersSheet({
    required this.story,
    required this.viewsCount, required this.likesCount,
    required this.viewers,    required this.replies,
    required this.onDelete,
  });

  @override
  State<_OwnerViewersSheet> createState() => _OwnerViewersSheetState();
}

class _OwnerViewersSheetState extends State<_OwnerViewersSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [

        // ── Thumbnail preview + stats (мисли расм 3) ─────────────
        Container(
          height: 160,
          color: Colors.black,
          child: Row(children: [
            // Story thumbnail
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 90,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: widget.story.mediaUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.story.mediaUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[800]))
                          : Container(color: Colors.grey[800]),
                    ),
                  ),
                ),
              ),
            ),
            // Камераи нав (мисли Instagram)
            Expanded(
              child: Center(
                child: Container(
                  width: 80,
                  height: 130,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          color: Colors.white54, size: 28),
                      SizedBox(height: 6),
                      Text('Нав', style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),

        // ── Stats row + delete ────────────────────────────────────
        Container(
          color: const Color(0xFF0A0A0A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            // 📊 Stats icon
            const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 8),
            // 👥 Viewers count — мисли расм 3
            const Icon(Icons.group_outlined,
                color: AppColors.neonBlue, size: 22),
            const SizedBox(width: 4),
            Text('${widget.viewsCount}',
              style: const TextStyle(
                color: AppColors.neonBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
            const Spacer(),
            // 🗑 Delete
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white54, size: 24),
              onPressed: widget.onDelete,
            ),
          ]),
        ),

        // ── Tabs: Ответы | Дидагон ────────────────────────────────
        TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: [
            Tab(text: 'Ответы (${widget.replies.length})'),
            Tab(text: 'Дидагон (${widget.viewsCount})'),
          ],
        ),

        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            // ── Replies ─────────────────────────────────────────
            _RepliesList(replies: widget.replies),
            // ── Viewers ─────────────────────────────────────────
            _ViewersList(viewers: widget.viewers),
          ],
        )),
      ]),
    );
  }
}

// ── Replies list (мисли расм 3 — "Ответы на истории") ───────────────
class _RepliesList extends StatelessWidget {
  final List replies;
  const _RepliesList({required this.replies});

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) {
      return const Center(child: Text('Ҳоло ҷавобе нест',
          style: TextStyle(color: Colors.white38, fontSize: 15)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: replies.length,
      itemBuilder: (_, i) {
        final r      = replies[i] as Map<String, dynamic>;
        final avatar = r['avatar']   as String? ?? '';
        final uname  = r['username'] as String? ?? '';
        final text   = r['text']     as String? ?? '';
        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white12,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? const Icon(Icons.person, color: Colors.white54) : null,
          ),
          title: Text(uname, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text(text, style: const TextStyle(
              color: Colors.white70, fontSize: 13)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.more_vert,
                color: Colors.white38, size: 20),
            const SizedBox(width: 8),
            SvgPicture.asset('assets/icons/share.svg',
              width: 20, height: 20,
              colorFilter: const ColorFilter.mode(
                  Colors.white38, BlendMode.srcIn)),
          ]),
        );
      },
    );
  }
}

// ── Viewers list (мисли расм 3 — "Кто просмотрел") ─────────────────
class _ViewersList extends StatelessWidget {
  final List viewers;
  const _ViewersList({required this.viewers});

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) {
      return const Center(child: Text('Ҳоло ҳеч кас ندиده',
          style: TextStyle(color: Colors.white38, fontSize: 15)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: viewers.length,
      itemBuilder: (_, i) {
        final v      = viewers[i] as Map<String, dynamic>;
        final avatar = v['avatar']   as String? ?? '';
        final uname  = v['username'] as String? ?? '';
        final liked  = v['liked']    as bool?   ?? false;
        final bio    = v['bio']      as String?  ?? '';
        return ListTile(
          leading: Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white12,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54) : null,
            ),
            // ❤ badge агар liked бошад
            if (liked)
              Positioned(bottom: -2, right: -2,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite,
                      color: Colors.white, size: 11),
                )),
          ]),
          title: Text(uname, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: bio.isNotEmpty
              ? Text(bio, style: const TextStyle(
                  color: Colors.white54, fontSize: 12)) : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.more_vert,
                color: Colors.white38, size: 20),
            const SizedBox(width: 8),
            SvgPicture.asset('assets/icons/share.svg',
              width: 20, height: 20,
              colorFilter: const ColorFilter.mode(
                  Colors.white38, BlendMode.srcIn)),
          ]),
        );
      },
    );
  }
}
