import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api/api_client.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../models/reel_model.dart';
import '../reels_repository.dart';
import '../../feed/comments/comments_screen.dart';
import '../../create/create_reel/create_reel_screen.dart';

// ─────────────────────────────────────────────
// REELS SCREEN
// ─────────────────────────────────────────────
class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _ReelsVM(ReelsRepository(ApiClient.instance))..load(),
      child: const _ReelsView(),
    );
  }
}

// ─────────────────────────────────────────────
// VIEW MODEL
// ─────────────────────────────────────────────
class _ReelsVM extends ChangeNotifier {
  final ReelsRepository _repo;
  _ReelsVM(this._repo);

  List<ReelModel> reels = [];
  bool loading = false;
  bool loadingMore = false;
  int _page = 1;

  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      reels = await _repo.fetchReels(page: 1);
      _page = 1;
      debugPrint('✅ Reels loaded: \${reels.length}');
    } catch (e) {
      error = e.toString();
      debugPrint('❌ Reels error: \$e');
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore) return;
    loadingMore = true;
    try {
      final more = await _repo.fetchReels(page: _page + 1);
      if (more.isNotEmpty) {
        reels = [...reels, ...more];
        _page++;
      }
    } catch (_) {}
    loadingMore = false;
    notifyListeners();
  }

  void toggleLike(String id) {
    reels = reels.map((r) {
      if (r.id == id) {
        final liked = !r.isLiked;
        return ReelModel(
          id: r.id, videoUrl: r.videoUrl, caption: r.caption,
          user: r.user, commentsCount: r.commentsCount,
          likesCount: r.likesCount + (liked ? 1 : -1),
          isLiked: liked,
        );
      }
      return r;
    }).toList();
    notifyListeners();
    _repo.likeReel(id);
  }

  void toggleSave(String id) {
    _repo.saveReel(id);
  }
}

// ─────────────────────────────────────────────
// REELS VIEW
// ─────────────────────────────────────────────
class _ReelsView extends StatefulWidget {
  const _ReelsView();

  @override
  State<_ReelsView> createState() => _ReelsViewState();
}

class _ReelsViewState extends State<_ReelsView>
    with WidgetsBindingObserver {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pause when route is not active
    final route = ModalRoute.of(context);
    if (route != null) {
      _isVisible = route.isCurrent;
      _updatePlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseAll();
    } else if (state == AppLifecycleState.resumed && _isVisible) {
      _resumeCurrent();
    }
  }

  void _pauseAll() {
    // Signal current item to pause
    _isVisible = false;
    setState(() {});
  }

  void _resumeCurrent() {
    _isVisible = true;
    setState(() {});
  }

  void _updatePlayback() {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_ReelsVM>();

    if (vm.loading && vm.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(
            color: Colors.white30, strokeWidth: 2)),
      );
    }

    if (vm.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, elevation: 0,
          title: const Text('Reels',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.video_collection_outlined,
                color: Colors.white24, size: 72),
            const SizedBox(height: 16),
            const Text('Reels нест',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (vm.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(vm.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center),
              )
            else
              const Text('Аввалин Reel-ро шумо гузоред!',
                  style: TextStyle(color: Colors.white38)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CreateReelScreen()))
              .then((created) {
                if (created == true) {
                  context.read<_ReelsVM>().load();
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFE1306C),
                      Color(0xFFF77737)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('+ Reel гузоред',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: vm.load,
              child: const Text('Боз кӯшиш кунед',
                  style: TextStyle(color: Colors.white38)),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        itemCount: vm.reels.length,
        onPageChanged: (i) {
          setState(() => _currentPage = i);
          // Load more when near end
          if (i >= vm.reels.length - 3) vm.loadMore();
        },
        itemBuilder: (_, i) => _ReelItem(
          reel: vm.reels[i],
          isActive: i == _currentPage && _isVisible,
          onLike: () => vm.toggleLike(vm.reels[i].id),
          onSave: () => vm.toggleSave(vm.reels[i].id),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SINGLE REEL ITEM
// ─────────────────────────────────────────────
class _ReelItem extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onSave;

  const _ReelItem({
    required this.reel,
    required this.isActive,
    required this.onLike,
    required this.onSave,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _paused = false;
  bool _showHeart = false;
  bool _saved = false;
  bool _following = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl?.play();
      // Mark view
      ApiClient.instance.post('/reels/${widget.reel.id}/view');
    } else if (!widget.isActive && old.isActive) {
      _ctrl?.pause();
    }
  }

  void _initVideo() {
    if (widget.reel.videoUrl.isEmpty) return;
    _ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl!.setLooping(true);
        if (widget.isActive) _ctrl!.play();
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePause() {
    if (_ctrl == null) return;
    setState(() => _paused = !_paused);
    _paused ? _ctrl!.pause() : _ctrl!.play();
  }

  void _doubleTapLike() {
    if (!widget.reel.isLiked) widget.onLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900),
        () { if (mounted) setState(() => _showHeart = false); });
  }

  void _openComments() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _ReelComments(reelId: widget.reel.id),
      ),
    ).then((_) { if (!_paused) _ctrl?.play(); });
  }

  void _share() {
    final url = 'https://raonson-v1.onrender.com/reels/${widget.reel.id}';
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
          const Text('Мубодила', style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white12,
                child: Icon(Icons.link, color: Colors.white, size: 18)),
            title: const Text('Линкро нусха кун',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Линк нусха шуд ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)),
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final reel = widget.reel;
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _togglePause,
      onDoubleTap: _doubleTapLike,
      child: Stack(fit: StackFit.expand, children: [

        // ── VIDEO ──
        if (_initialized && _ctrl != null)
          FittedBox(fit: BoxFit.cover,
            child: SizedBox(
              width: _ctrl!.value.size.width,
              height: _ctrl!.value.size.height,
              child: VideoPlayer(_ctrl!),
            ))
        else
          Container(color: Colors.black,
            child: const Center(child: CircularProgressIndicator(
                color: Colors.white30, strokeWidth: 2))),

        // ── GRADIENT OVERLAY ──
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Colors.transparent,
                Color(0x88000000), Color(0xDD000000)],
              stops: [0, 0.4, 0.75, 1],
            ),
          ),
        ),

        // ── PAUSE ICON ──
        if (_paused)
          const Center(
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white60, size: 80),
          ),

        // ── DOUBLE TAP HEART ──
        if (_showHeart)
          const Center(
            child: _HeartBurst(),
          ),

        // ── VIDEO PROGRESS ──
        if (_initialized && _ctrl != null)
          Positioned(top: 0, left: 0, right: 0,
            child: ValueListenableBuilder(
              valueListenable: _ctrl!,
              builder: (_, val, __) {
                final pos = val.position.inMilliseconds;
                final dur = val.duration.inMilliseconds;
                return LinearProgressIndicator(
                  value: dur > 0 ? pos / dur : 0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 2,
                );
              },
            ),
          ),

        // ── TOP BAR ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16, right: 16,
          child: Row(children: [
            const Text('Reels',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 20,
                    letterSpacing: -0.5)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateReelScreen())),
              child: const Icon(Icons.add_box_outlined,
                  color: Colors.white, size: 26),
            ),
          ]),
        ),

        // ── RIGHT ACTIONS ──
        Positioned(
          right: 12,
          bottom: size.height * 0.12,
          child: Column(children: [
            // LIKE
            _RightBtn(
              onTap: widget.onLike,
              onDoubleTap: _doubleTapLike,
              icon: reel.isLiked ? Icons.favorite : Icons.favorite_border,
              color: reel.isLiked ? const Color(0xFFFF3040) : Colors.white,
              label: _fmt(reel.likesCount),
            ),
            const SizedBox(height: 20),
            // COMMENT
            _RightBtn(
              onTap: _openComments,
              icon: Icons.mode_comment_outlined,
              color: Colors.white,
              label: _fmt(reel.commentsCount),
            ),
            const SizedBox(height: 20),
            // SHARE
            _RightBtn(
              onTap: _share,
              icon: Icons.send_outlined,
              color: Colors.white,
              label: '',
              rotate: -0.4,
            ),
            const SizedBox(height: 20),
            // SAVE
            _RightBtn(
              onTap: () {
                setState(() => _saved = !_saved);
                widget.onSave();
              },
              icon: _saved ? Icons.bookmark : Icons.bookmark_border,
              color: _saved ? Colors.yellow : Colors.white,
              label: '',
            ),
            const SizedBox(height: 20),
            // Spinning disc (music)
            _SpinningDisc(avatar: reel.user.avatar),
          ]),
        ),

        // ── BOTTOM INFO ──
        Positioned(
          left: 14, right: 80,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User row
              Row(children: [
                Avatar(imageUrl: reel.user.avatar, size: 38, glowBorder: true),
                const SizedBox(width: 10),
                Text(reel.user.username,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                if (reel.user.verified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 14),
                ],
                const SizedBox(width: 12),
                // Follow button
                if (!_following)
                  GestureDetector(
                    onTap: () {
                      setState(() => _following = true);
                      ApiClient.instance.post('/follow/${reel.user.id}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 1.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Пайравӣ',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
              ]),
              if (reel.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(reel.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              // Music row
              Row(children: [
                const Icon(Icons.music_note, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  reel.caption.isNotEmpty
                      ? reel.caption.split(' ').take(4).join(' ')
                      : 'Оригинал аудио',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }
}

// ─────────────────────────────────────────────
// RIGHT BUTTON
// ─────────────────────────────────────────────
class _RightBtn extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final IconData icon;
  final Color color;
  final String label;
  final double rotate;

  const _RightBtn({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.label,
    this.onDoubleTap,
    this.rotate = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Transform.rotate(angle: rotate,
          child: Icon(icon, color: color, size: 30,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)])),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white,
              fontSize: 13, fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SPINNING DISC (music)
// ─────────────────────────────────────────────
class _SpinningDisc extends StatefulWidget {
  final String avatar;
  const _SpinningDisc({required this.avatar});

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this,
        duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 2),
          color: Colors.black,
        ),
        child: ClipOval(
          child: widget.avatar.isNotEmpty
              ? CachedNetworkImage(imageUrl: widget.avatar, fit: BoxFit.cover)
              : const Icon(Icons.music_note, color: Colors.white54, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEART BURST ANIMATION
// ─────────────────────────────────────────────
class _HeartBurst extends StatefulWidget {
  const _HeartBurst();

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))
      ..forward();
    _scale = Tween(begin: 0.3, end: 1.4).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: const Icon(Icons.favorite,
              color: Colors.white, size: 120,
              shadows: [Shadow(blurRadius: 30, color: Colors.black54)]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REEL COMMENTS SHEET
// ─────────────────────────────────────────────
class _ReelComments extends StatefulWidget {
  final String reelId;
  const _ReelComments({required this.reelId});

  @override
  State<_ReelComments> createState() => _ReelCommentsState();
}

class _ReelCommentsState extends State<_ReelComments> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(
          '/reels/${widget.reelId}/comments');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['comments'] ?? []);
        setState(() {
          _comments = List<Map<String, dynamic>>.from(list);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post(
          '/reels/${widget.reelId}/comments', body: {'text': text});
      _ctrl.clear();
      _load();
    } catch (_) {}
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(margin: const EdgeInsets.symmetric(vertical: 8),
        width: 36, height: 4,
        decoration: BoxDecoration(color: Colors.white24,
            borderRadius: BorderRadius.circular(2))),
      Text('Комментарияҳо (${_comments.length})',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 4),
      const Divider(color: Colors.white12),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: Colors.white30, strokeWidth: 2))
            : _comments.isEmpty
                ? const Center(child: Text('Аввалин бошед!',
                    style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      final u = c['user'] as Map? ?? {};
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          CircleAvatar(radius: 16,
                              backgroundImage: (u['avatar'] ?? '').isNotEmpty
                                  ? NetworkImage(u['avatar']) : null,
                              child: (u['avatar'] ?? '').isEmpty
                                  ? const Icon(Icons.person,
                                      color: Colors.white54, size: 16) : null),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['username'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(c['text'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                            ],
                          )),
                        ]),
                      );
                    },
                  ),
      ),
      // Input
      SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, bottom: 8,
            top: 8 + MediaQuery.of(context).viewInsets.bottom / 2,
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Комментария нависед...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: _sending
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0095F6)))
                  : const Icon(Icons.send_rounded,
                      color: Color(0xFF0095F6), size: 28),
            ),
          ]),
        ),
      ),
    ]);
  }
}
