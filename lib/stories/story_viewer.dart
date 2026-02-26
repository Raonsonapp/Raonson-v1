import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../models/story_model.dart';
import '../core/api/api_client.dart';
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
  bool _paused = false;

  // Reply
  final _replyCtrl = TextEditingController();
  bool _showReply = false;
  bool _sendingReply = false;

  // Like
  bool _liked = false;

  bool get _isVideo => widget.story.mediaType == 'video';

  // Viewers data (for owner)
  int _viewsCount = 0;
  int _likesCount = 0;
  List _viewers = [];
  List _likers = [];
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    } else {
      _startProgress(const Duration(seconds: 5));
    }
    // Mark as viewed
    _markViewed();
  }

  Future<void> _markViewed() async {
    try {
      await ApiClient.instance.post('/stories/\${widget.story.id}/view');
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
    _progressCtrl.stop();
    _timer?.cancel();
    _videoCtrl?.pause();
    setState(() => _paused = true);
  }

  void _resume() {
    _progressCtrl.forward();
    final remaining = _progressCtrl.duration! *
        (1 - _progressCtrl.value);
    _timer = Timer(remaining, _close);
    _videoCtrl?.play();
    setState(() => _paused = false);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
    widget.onComplete();
  }

  Future<void> _showViewersPanel() async {
    _pause();
    // Load viewers from API
    try {
      final res = await ApiClient.instance.get(
          '/stories/\${widget.story.id}/viewers');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _viewsCount = data['viewsCount'] ?? 0;
        _likesCount = data['likesCount'] ?? 0;
        _viewers = data['viewers'] ?? [];
        _likers = data['likers'] ?? [];
        _isOwner = true;
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ViewersPanel(
        viewsCount: _viewsCount,
        likesCount: _likesCount,
        viewers: _viewers,
        likers: _likers,
        isOwner: _isOwner,
      ),
    ).then((_) => _resume());
  }

  void _toggleLike() async {
    setState(() => _liked = !_liked);
    if (_liked) _showHeartAnim();
    try {
      await ApiClient.instance.post('/stories/\${widget.story.id}/like');
    } catch (_) {}
  }

  void _showHeartAnim() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _HeartOverlay(onDone: () {
      entry.remove();
    }));
    overlay.insert(entry);
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    try {
      // Send as DM/comment to story owner
      await ApiClient.instance.post('/stories/${widget.story.id}/reply',
          body: {'text': text});
      _replyCtrl.clear();
      setState(() { _showReply = false; _sendingReply = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Фиристода шуд ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      setState(() => _sendingReply = false);
    }
  }

  void _showShareSheet() {
    _pause();
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
            padding: EdgeInsets.all(12),
            child: Text('Мубодила', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: 16)),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white12,
                child: Icon(Icons.send, color: Colors.white, size: 20)),
            title: const Text('Ба дӯст фиристед',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white12,
                child: Icon(Icons.link, color: Colors.white, size: 20)),
            title: const Text('Линк нусха кун',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ).then((_) => _resume());
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
        // Swipe UP = show viewers (owner only)
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity! < -300) {
            _showViewersPanel();
          }
        },
        // Tap left/right to skip or close
        onTapUp: (d) {
          if (_showReply) return;
          final x = d.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if (x < w * 0.3) {
            // prev - just close for now
            _close();
          } else if (x > w * 0.7) {
            _close();
          } else {
            // middle tap = pause/resume
            _paused ? _resume() : _pause();
          }
        },
        // Hold to pause
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        child: Stack(fit: StackFit.expand, children: [
          // ── Media ──
          _isVideo ? _buildVideo() : _buildImage(),

          // ── Gradient overlays ──
          // Top gradient for header
          Positioned(
            top: 0, left: 0, right: 0, height: 140,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          // Bottom gradient for actions
          Positioned(
            bottom: 0, left: 0, right: 0, height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Progress bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8, right: 8,
            child: _isVideo && !_videoReady
                ? const SizedBox()
                : AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => LinearProgressIndicator(
                      value: _progressCtrl.value,
                      backgroundColor: Colors.white30,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
          ),

          // ── Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 12, right: 12,
            child: Row(children: [
              // Avatar
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF77737), Color(0xFFE1306C),
                      Color(0xFF833AB4)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    backgroundColor: Colors.black,
                    backgroundImage: widget.story.userAvatar.isNotEmpty
                        ? NetworkImage(widget.story.userAvatar) : null,
                    child: widget.story.userAvatar.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white54, size: 20) : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Username + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.story.username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [Shadow(blurRadius: 4,
                                color: Colors.black)])),
                    Text(_timeAgo(widget.story.expiresAt
                        .subtract(const Duration(hours: 24))),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              // Pause indicator
              if (_paused)
                const Icon(Icons.pause_circle_filled,
                    color: Colors.white60, size: 20),
              const SizedBox(width: 8),
              // Close
              GestureDetector(
                onTap: _close,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 24),
                ),
              ),
            ]),
          ),

          // ── Bottom actions ──
          // Swipe up hint + viewers count
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 80,
            left: 0, right: 0,
            child: GestureDetector(
              onTap: _showViewersPanel,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.keyboard_arrow_up,
                    color: Colors.white60, size: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.remove_red_eye_outlined,
                      color: Colors.white60, size: 14),
                  const SizedBox(width: 4),
                  Text('\$_viewsCount кас дид',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                  if (_likesCount > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite,
                        color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('\$_likesCount',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ]),
              ]),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16, right: 16,
            child: _showReply
                ? _buildReplyInput()
                : _buildActions(),
          ),
        ]),
      ),
    );
  }

  Widget _buildActions() {
    return Row(children: [
      // Reply field (tap to open)
      Expanded(
        child: GestureDetector(
          onTap: () {
            _pause();
            setState(() => _showReply = true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white38, width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Жавоб бериш...',
              style: TextStyle(color: Colors.white.withOpacity(0.7),
                  fontSize: 14),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Like
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
      const SizedBox(width: 16),
      // Share
      GestureDetector(
        onTap: _showShareSheet,
        child: Transform.rotate(
          angle: -0.4,
          child: const Icon(Icons.send, color: Colors.white, size: 26),
        ),
      ),
    ]);
  }

  Widget _buildReplyInput() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _replyCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendReply(),
          onEditingComplete: () {},
          decoration: InputDecoration(
            hintText: '${widget.story.username}-га жавоб бериш...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            suffixIcon: IconButton(
              icon: _sendingReply
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Color(0xFF0095F6), size: 20),
              onPressed: _sendReply,
            ),
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

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.story.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white30)),
      errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image,
              color: Colors.white38, size: 72)),
    );
  }

  Widget _buildVideo() {
    if (!_videoReady) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white30));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _videoCtrl!.value.size.width,
        height: _videoCtrl!.value.size.height,
        child: VideoPlayer(_videoCtrl!),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ҳозир';
    if (diff.inMinutes < 60) return '${diff.inMinutes}д';
    if (diff.inHours < 24) return '${diff.inHours}с';
    return '${diff.inDays}р';
  }
}

// ── Heart animation overlay ──
class _HeartOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _HeartOverlay({required this.onDone});

  @override
  State<_HeartOverlay> createState() => _HeartOverlayState();
}

class _HeartOverlayState extends State<_HeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _scale = Tween(begin: 0.5, end: 1.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: const Icon(Icons.favorite,
                color: Colors.white, size: 100,
                shadows: [Shadow(blurRadius: 20, color: Colors.black54)]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// VIEWERS PANEL - Instagram style
// ─────────────────────────────────────────────
class _ViewersPanel extends StatefulWidget {
  final int viewsCount;
  final int likesCount;
  final List viewers;
  final List likers;
  final bool isOwner;

  const _ViewersPanel({
    required this.viewsCount,
    required this.likesCount,
    required this.viewers,
    required this.likers,
    required this.isOwner,
  });

  @override
  State<_ViewersPanel> createState() => _ViewersPanelState();
}

class _ViewersPanelState extends State<_ViewersPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(children: [
        // Handle
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),

        if (!widget.isOwner)
          const Expanded(
            child: Center(
              child: Text('Танҳо соҳиби сторис метавонад бинад',
                  style: TextStyle(color: Colors.white54)),
            ),
          )
        else ...[
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              _StatBadge(
                icon: Icons.remove_red_eye_outlined,
                count: widget.viewsCount,
                label: 'кас дид',
                color: Colors.white,
              ),
              const SizedBox(width: 24),
              _StatBadge(
                icon: Icons.favorite,
                count: widget.likesCount,
                label: 'лайк',
                color: Colors.red,
              ),
            ]),
          ),

          // Tabs
          TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'Дидагон (${widget.viewsCount})'),
              Tab(text: 'Лайкҳо (${widget.likesCount})'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UserList(users: widget.viewers),
                _UserList(users: widget.likers),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon, required this.count,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$count', style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(
            color: Colors.white54, fontSize: 12)),
      ]),
    ]);
  }
}

class _UserList extends StatelessWidget {
  final List users;
  const _UserList({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Text('Ҳоло ҳеч кас нест',
            style: TextStyle(color: Colors.white38, fontSize: 15)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i] as Map<String, dynamic>;
        final avatar = u['avatar'] as String? ?? '';
        final username = u['username'] as String? ?? '';
        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white12,
            backgroundImage: avatar.isNotEmpty
                ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? const Icon(Icons.person, color: Colors.white54, size: 20)
                : null,
          ),
          title: Text(username,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}
