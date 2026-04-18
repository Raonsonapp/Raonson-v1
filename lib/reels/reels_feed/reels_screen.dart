import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api/api_client.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../models/reel_model.dart';
import '../reels_repository.dart';
import '../../app/app_theme.dart';
import '../../create/create_reel/create_reel_screen.dart';

// ══════════════════════════════════════════════════════════════════
// REELS SCREEN
// ══════════════════════════════════════════════════════════════════
class ReelsScreen extends StatelessWidget {
  final bool isActive;
  const ReelsScreen({super.key, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _ReelsVM(ReelsRepository(ApiClient.instance))..load(),
      child: _ReelsView(isActive: isActive),
    );
  }
}

// ── ViewModel ────────────────────────────────────────────────────
class _ReelsVM extends ChangeNotifier {
  final ReelsRepository _repo;
  _ReelsVM(this._repo);

  List<ReelModel> reels     = [];
  bool loading              = false;
  bool loadingMore          = false;
  int  _page                = 1;
  String? error;

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try {
      reels  = await _repo.fetchReels(page: 1);
      _page  = 1;
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore) return;
    loadingMore = true;
    try {
      final more = await _repo.fetchReels(page: _page + 1);
      if (more.isNotEmpty) { reels = [...reels, ...more]; _page++; }
    } catch (_) {}
    loadingMore = false; notifyListeners();
  }

  void toggleLike(String id) {
    reels = reels.map((r) {
      if (r.id != id) return r;
      final liked = !r.isLiked;
      return ReelModel(
        id: r.id, videoUrl: r.videoUrl, caption: r.caption,
        user: r.user, commentsCount: r.commentsCount,
        likesCount: r.likesCount + (liked ? 1 : -1), isLiked: liked,
      );
    }).toList();
    notifyListeners();
    _repo.likeReel(id);
  }

  void toggleSave(String id) => _repo.saveReel(id);
}

// ── View ──────────────────────────────────────────────────────────
class _ReelsView extends StatefulWidget {
  final bool isActive;
  const _ReelsView({this.isActive = true});
  @override
  State<_ReelsView> createState() => _ReelsViewState();
}

class _ReelsViewState extends State<_ReelsView> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  // "Рилсҳо | Дӯстон" toggle мисли расм
  bool _friendsFilter = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_ReelsVM>();

    // Loading
    if (vm.loading && vm.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.storyStart))),
      );
    }

    // Empty
    if (vm.reels.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF77737)],
              ),
            ),
            child: const Icon(Icons.video_collection_outlined,
                color: Colors.white, size: 40)),
          const SizedBox(height: 20),
          const Text('Reels нест', style: TextStyle(
              color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (vm.error != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(vm.error!, style: const TextStyle(
                  color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center))
          else
            const Text('Аввалин Reel-ро шумо гузоред!',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateReelScreen()))
                .then((ok) { if (ok == true) context.read<_ReelsVM>().load(); }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF77737)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('+ Reel гузоред',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: vm.load,
              child: const Text('Боз кӯшиш кунед',
                  style: TextStyle(color: Colors.white38))),
        ])),
      );
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        itemCount: vm.reels.length,
        onPageChanged: (i) {
          setState(() => _currentPage = i);
          if (i >= vm.reels.length - 3) vm.loadMore();
        },
        itemBuilder: (_, i) => _ReelItem(
          reel: vm.reels[i],
          isActive: i == _currentPage && widget.isActive,
          friendsFilter: _friendsFilter,
          onLike: () => vm.toggleLike(vm.reels[i].id),
          onSave: () => vm.toggleSave(vm.reels[i].id),
          onToggleFilter: () => setState(() => _friendsFilter = !_friendsFilter),
          onAddReel: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateReelScreen()))
              .then((ok) { if (ok == true) vm.load(); }),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SINGLE REEL ITEM — айнан мисли расм
// ══════════════════════════════════════════════════════════════════
class _ReelItem extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final bool friendsFilter;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onToggleFilter;
  final VoidCallback onAddReel;

  const _ReelItem({
    required this.reel,
    required this.isActive,
    required this.friendsFilter,
    required this.onLike,
    required this.onSave,
    required this.onToggleFilter,
    required this.onAddReel,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _paused      = false;
  bool _showHeart   = false;
  bool _saved       = false;
  bool _following   = false;
  // Retweet count (local)
  int  _retweetCount = 0;

  @override
  void initState() { super.initState(); _initVideo(); }

  @override
  void deactivate() { _ctrl?.pause(); super.deactivate(); }

  @override
  void activate() {
    super.activate();
    if (widget.isActive && _initialized) _ctrl?.play();
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl?.setVolume(1.0);
      _ctrl?.play();
      ApiClient.instance.post('/reels/${widget.reel.id}/view');
    } else if (!widget.isActive && old.isActive) {
      _ctrl?.pause();
    }
  }

  void _initVideo() {
    if (widget.reel.videoUrl.isEmpty) return;
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl!.setLooping(true);
        if (widget.isActive) { _ctrl!.setVolume(1.0); _ctrl!.play(); }
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  void _togglePause() {
    if (_ctrl == null) return;
    setState(() => _paused = !_paused);
    _paused ? _ctrl!.pause() : _ctrl!.play();
  }

  void _doubleTapLike() {
    if (!widget.reel.isLiked) widget.onLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openComments() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _ReelComments(reelId: widget.reel.id),
      ),
    ).then((_) { if (!_paused) _ctrl?.play(); });
  }

  void _share() {
    final url = 'https://raonson-v1.onrender.com/reels/${widget.reel.id}';
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Линк нусха шуд ✓'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2)));
            },
          ),
          const SizedBox(height: 8),
        ],
      )),
    ).then((_) { if (!_paused) _ctrl?.play(); });
    setState(() => _retweetCount++);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return n > 0 ? '$n' : '';
  }

  @override
  Widget build(BuildContext context) {
    final reel   = widget.reel;
    final size   = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: _togglePause,
      onDoubleTap: _doubleTapLike,
      child: Stack(fit: StackFit.expand, children: [

        // ── Video / Placeholder ────────────────────────────────
        if (_initialized && _ctrl != null)
          FittedBox(fit: BoxFit.cover,
            child: SizedBox(
              width:  _ctrl!.value.size.width,
              height: _ctrl!.value.size.height,
              child:  VideoPlayer(_ctrl!),
            ))
        else
          Container(color: AppColors.bg,
            child: const Center(child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.storyStart)))),

        // ── Gradient overlay ───────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                Color(0x77000000), Colors.transparent,
                Color(0x44000000), Color(0xEE000000),
              ],
              stops: [0, 0.35, 0.65, 1],
            ),
          ),
        ),

        // ── Pause icon ─────────────────────────────────────────
        if (_paused)
          const Center(child: Icon(Icons.play_arrow_rounded,
              color: Colors.white54, size: 80,
              shadows: [Shadow(blurRadius: 20, color: Colors.black54)])),

        // ── Double-tap heart ───────────────────────────────────
        if (_showHeart) const Center(child: _HeartBurst()),

        // ── Video progress bar ─────────────────────────────────
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
                  valueColor: const AlwaysStoppedAnimation(AppColors.storyStart),
                  minHeight: 2,
                );
              },
            )),

        // ── TOP BAR — "Рилсҳо | Дӯстон ∨" + "+" мисли расм ───
        Positioned(
          top: top + 12, left: 0, right: 0,
          child: Row(children: [
            const SizedBox(width: 16),
            // Title with filter toggle
            GestureDetector(
              onTap: widget.onToggleFilter,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  widget.friendsFilter ? 'Дӯстон' : 'Рилсҳо',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                  ),
                ),
                const SizedBox(width: 6),
                const Text('|',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  widget.friendsFilter ? 'Рилсҳо' : 'Дӯстон',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 16,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70, size: 20),
              ]),
            ),
            const Spacer(),
            // "+" — нашри Reel
            GestureDetector(
              onTap: widget.onAddReel,
              child: const Padding(padding: EdgeInsets.all(8),
                child: Icon(Icons.add, color: Colors.white, size: 28,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
            ),
            const SizedBox(width: 8),
          ]),
        ),

        // ── RIGHT ACTIONS — мисли расм: ♡·💬·🔄·↗·🔖···· ──────
        Positioned(
          right: 10,
          bottom: bottom + size.height * 0.10,
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ♡ Like
            _SvgAction(
              svgPath: reel.isLiked
                  ? 'assets/icons/heart_filled.svg'
                  : 'assets/icons/heart.svg',
              fallback: reel.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: reel.isLiked ? Colors.red : Colors.white,
              count: _fmt(reel.likesCount),
              onTap: widget.onLike,
            ),
            const SizedBox(height: 22),

            // 💬 Comment
            _SvgAction(
              svgPath: 'assets/icons/comment.svg',
              fallback: Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              count: _fmt(reel.commentsCount),
              onTap: _openComments,
            ),
            const SizedBox(height: 22),

            // 🔄 Retweet
            _SvgAction(
              svgPath: 'assets/icons/retweet.svg',
              fallback: Icons.repeat_rounded,
              color: Colors.white,
              count: _fmt(_retweetCount),
              onTap: () => setState(() => _retweetCount++),
            ),
            const SizedBox(height: 22),

            // ↗ Share
            _SvgAction(
              svgPath: 'assets/icons/share.svg',
              fallback: Icons.ios_share_rounded,
              color: Colors.white,
              count: '',
              onTap: _share,
            ),
            const SizedBox(height: 22),

            // 🔖 Save
            _SvgAction(
              svgPath: _saved
                  ? 'assets/icons/save_filled.svg'
                  : 'assets/icons/save.svg',
              fallback: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white,
              count: '',
              onTap: () { setState(() => _saved = !_saved); widget.onSave(); },
            ),
            const SizedBox(height: 22),

            // ··· More
            GestureDetector(
              onTap: () {},
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
              ]),
            ),
            const SizedBox(height: 16),

            // 🎵 Spinning disc
            _SpinningDisc(avatar: reel.user.avatar),
          ]),
        ),

        // ── BOTTOM LEFT — avatar · username · follow · caption · music ──
        Positioned(
          left: 14, right: 90,
          bottom: bottom + 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User row
              Row(children: [
                Avatar(imageUrl: reel.user.avatar, size: 40, glowBorder: true),
                const SizedBox(width: 10),
                Flexible(child: Text(reel.user.username,
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (reel.user.verified) ...[ const SizedBox(width: 4),
                  const VerifiedBadge(size: 14)],
                const SizedBox(width: 10),
                // "Пайравӣ кунед" button мисли расм
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
                        border: Border.all(color: Colors.white, width: 1.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Пайравӣ кунед',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 12,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                    ),
                  ),
              ]),

              // Caption
              if (reel.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(reel.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 14,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),

              // 🎵 Music row мисли расм
              Row(children: [
                const Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 15,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                const SizedBox(width: 5),
                Text(
                  reel.caption.isNotEmpty
                      ? reel.caption.split(' ').take(3).join(' ')
                      : 'оригинал садо',
                  style: const TextStyle(color: Colors.white70, fontSize: 13,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── SVG Action button (right side) ─────────────────────────────────
class _SvgAction extends StatelessWidget {
  final String   svgPath;
  final IconData fallback;
  final Color    color;
  final String   count;
  final VoidCallback onTap;

  const _SvgAction({
    required this.svgPath,
    required this.fallback,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(
          svgPath, width: 30, height: 30,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          placeholderBuilder: (_) => Icon(fallback, color: color, size: 30,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
        ),
        if (count.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(count, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
        ],
      ]),
    );
  }
}

// ── Spinning music disc ─────────────────────────────────────────────
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
        duration: const Duration(seconds: 5))..repeat();
  }
  @override void dispose() { _spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spin,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: AppColors.storyGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Colors.black),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: widget.avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.avatar, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white54, size: 20))
                : const Icon(Icons.music_note_rounded,
                    color: Colors.white54, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Heart burst animation ───────────────────────────────────────────
class _HeartBurst extends StatefulWidget {
  const _HeartBurst();
  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _scale   = Tween(begin: 0.3, end: 1.4).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Opacity(opacity: _opacity.value,
      child: Transform.scale(scale: _scale.value,
        child: const Icon(Icons.favorite, color: Colors.white, size: 120,
          shadows: [Shadow(blurRadius: 30, color: Colors.black54)]))));
}

// ── Reel Comments sheet ─────────────────────────────────────────────
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
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance
          .get('/reels/${widget.reelId}/comments');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['comments'] ?? []);
        setState(() {
          _comments = List<Map<String, dynamic>>.from(list);
          _loading  = false;
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
      Container(margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36, height: 4,
        decoration: BoxDecoration(color: Colors.white24,
            borderRadius: BorderRadius.circular(2))),
      Text('Комментарияҳо (${_comments.length})',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 4),
      const Divider(color: Colors.white10),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.storyStart)))
            : _comments.isEmpty
                ? const Center(child: Text('Аввалин бошед!',
                    style: TextStyle(color: Colors.white38, fontSize: 15)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      final u = c['user'] as Map? ?? {};
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          CircleAvatar(radius: 18,
                            backgroundColor: AppColors.card,
                            backgroundImage: (u['avatar'] ?? '').isNotEmpty
                                ? NetworkImage(u['avatar']) : null,
                            child: (u['avatar'] ?? '').isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white54, size: 18) : null),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['username'] ?? '',
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 3),
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
      SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, bottom: 8,
            top: 8 + MediaQuery.of(context).viewInsets.bottom / 2),
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
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: _sending
                  ? const SizedBox(width: 26, height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.neonBlue)))
                  : const Icon(Icons.send_rounded,
                      color: AppColors.neonBlue, size: 28)),
          ]),
        ),
      ),
    ]);
  }
}
