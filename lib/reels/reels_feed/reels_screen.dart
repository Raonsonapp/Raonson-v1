import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';
import '../../models/reel_model.dart';
import '../reels_repository.dart';
import '../../app/app_theme.dart';
import '../../create/create_reel/create_reel_screen.dart';

import '../../core/ads/ads_manager.dart';
import '../../core/ads/rewarded_ad_flow.dart';

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

class _ReelsVM extends ChangeNotifier {
  final ReelsRepository _repo;
  _ReelsVM(this._repo);

  List<ReelModel> reels = [];
  bool loading = false;
  bool loadingMore = false;
  int _page = 1;
  String? error;
  bool isMuted = false;
  bool _friendsFilter = false;
  bool get friendsFilter => _friendsFilter;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      reels = await _repo.fetchReels(page: 1, smart: true);
      _page = 1;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore) return;
    loadingMore = true;
    try {
      final more = await _repo.fetchReels(page: _page + 1, smart: true);
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
      if (r.id != id) return r;
      final liked = !r.isLiked;
      return r.copyWith(
          isLiked: liked, likesCount: r.likesCount + (liked ? 1 : -1));
    }).toList();
    notifyListeners();
  }

  void toggleSave(String id) {
    reels = reels.map((r) {
      if (r.id != id) return r;
      return r.copyWith(isSaved: !r.isSaved);
    }).toList();
    notifyListeners();
  }

  void toggleMute() {
    isMuted = !isMuted;
    notifyListeners();
  }

  void toggleFilter() {
    _friendsFilter = !_friendsFilter;
    notifyListeners();
    load();
  }
}

class _ReelsView extends StatefulWidget {
  final bool isActive;
  const _ReelsView({this.isActive = true});
  @override
  State<_ReelsView> createState() => _ReelsViewState();
}

class _ReelsViewState extends State<_ReelsView> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  final Map<int, VideoPlayerController> _preloaded = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AdsManager.instance.init();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final ctrl in _preloaded.values) {
      ctrl.dispose();
    }
    _preloaded.clear();
    super.dispose();
  }

  void _onPageChanged(int i, _ReelsVM vm) {
    setState(() => _currentPage = i);
    if (i >= vm.reels.length - 3) vm.loadMore();
    _preloadAhead(i, vm);
    _disposeOld(i);
    // Trigger interstitial every 5 reels
    AdsManager.instance.onReelSwiped();
  }

  void _preloadAhead(int current, _ReelsVM vm) {
    for (int j = current + 1; j <= current + 2; j++) {
      if (j >= vm.reels.length) break;
      if (_preloaded.containsKey(j)) continue;
      final url = vm.reels[j].videoUrl;
      if (url.isEmpty) continue;
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _preloaded[j] = ctrl;
      ctrl.initialize().then((_) {
        ctrl.setLooping(true);
        ctrl.setVolume(0);
      });
    }
  }

  void _disposeOld(int current) {
    final toRemove = _preloaded.keys.where((k) => k < current - 1).toList();
    for (final k in toRemove) {
      _preloaded[k]?.dispose();
      _preloaded.remove(k);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_ReelsVM>();

    if (vm.loading && vm.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.storyStart),
          ),
        ),
      );
    }

    if (vm.reels.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_collection_outlined,
                  color: AppColors.grey, size: 48),
              const SizedBox(height: 12),
              const Text('Рилсҳо нест',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: vm.load,
                child: const Text('Боз кӯшиш кун',
                    style: TextStyle(color: AppColors.neonBlue)),
              ),
            ],
          ),
        ),
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
        onPageChanged: (i) => _onPageChanged(i, vm),
        itemBuilder: (_, i) => _ReelItem(
          reel: vm.reels[i],
          isActive: i == _currentPage && widget.isActive,
          isMuted: vm.isMuted,
          preloadCtrl: _preloaded[i],
          onLike: () => vm.toggleLike(vm.reels[i].id),
          onSave: () => vm.toggleSave(vm.reels[i].id),
          onMuteToggle: vm.toggleMute,
          onAddReel: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateReelScreen()),
          ).then((ok) {
            if (ok == true && context.mounted) vm.load();
          }),
          onDownload: () => showRewardedAdFlow(
            context,
            rewardType: RewardType.videoDownload,
          ),
        ),
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final ReelModel              reel;
  final bool                   isActive;
  final bool                   isMuted;
  final VideoPlayerController? preloadCtrl;
  final VoidCallback           onLike;
  final VoidCallback           onSave;
  final VoidCallback           onMuteToggle;
  final VoidCallback           onAddReel;
  final Future<bool> Function() onDownload;

  const _ReelItem({
    required this.reel,
    required this.isActive,
    required this.isMuted,
    this.preloadCtrl,
    required this.onLike,
    required this.onSave,
    required this.onMuteToggle,
    required this.onAddReel,
    required this.onDownload,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _showHeart   = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.preloadCtrl != null &&
        widget.preloadCtrl!.value.isInitialized) {
      _ctrl        = widget.preloadCtrl;
      _initialized = true;
      if (widget.isActive) _ctrl!.play();
      setState(() {});
      return;
    }

    final url = widget.reel.videoUrl;
    if (url.isEmpty) return;

    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await _ctrl!.initialize();
    _ctrl!.setLooping(true);
    _ctrl!.setVolume(widget.isMuted ? 0 : 1);
    if (widget.isActive) _ctrl!.play();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && _initialized) {
      _ctrl?.setVolume(widget.isMuted ? 0 : 1);
      _ctrl?.play();
    } else {
      _ctrl?.pause();
    }
  }

  @override
  void dispose() {
    if (widget.preloadCtrl == null) _ctrl?.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    widget.onLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    try {
      await widget.onDownload();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          onTap:       widget.onMuteToggle,
          child: _initialized && _ctrl != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:  _ctrl!.value.size.width,
                    height: _ctrl!.value.size.height,
                    child:  VideoPlayer(_ctrl!),
                  ),
                )
              : const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white30),
                  ),
                ),
        ),

        // Double-tap heart
        if (_showHeart)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 350),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Opacity(
                opacity: (1 - (v - 0.3) * 2).clamp(0, 1),
                child: Transform.scale(
                  scale: v,
                  child: const Icon(Icons.favorite,
                      color: Colors.white, size: 90),
                ),
              ),
            ),
          ),

        // Right action bar
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _ActionBtn(
                icon: widget.reel.isLiked
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: widget.reel.isLiked ? Colors.red : Colors.white,
                count: widget.reel.likesCount,
                onTap: widget.onLike,
              ),
              const SizedBox(height: 18),
              _ActionBtn(
                icon:  Icons.comment_rounded,
                count: widget.reel.commentsCount,
                onTap: () {},
              ),
              const SizedBox(height: 18),
              _ActionBtn(
                icon:  Icons.share_rounded,
                onTap: () => Share.share(widget.reel.videoUrl),
              ),
              const SizedBox(height: 18),
              _ActionBtn(
                icon: widget.reel.isSaved
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                onTap: widget.onSave,
              ),
              const SizedBox(height: 18),
              // Download (rewarded ad)
              _ActionBtn(
                icon:  _downloading
                    ? Icons.hourglass_bottom_rounded
                    : Icons.download_rounded,
                color: AppColors.neonBlue,
                onTap: _downloading ? null : _handleDownload,
              ),
            ],
          ),
        ),

        // Bottom info
        Positioned(
          left:   12,
          right:  80,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.reel.user.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              if (widget.reel.caption.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.reel.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Mute indicator
        if (widget.isMuted)
          Positioned(
            top:   60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_off_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;
  final int?          count;
  final Color         color;

  const _ActionBtn({
    required this.icon,
    this.onTap,
    this.count,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
          if (count != null && count! > 0) ...[
            const SizedBox(height: 3),
            Text(
              count! >= 1000
                  ? '${(count! / 1000).toStringAsFixed(1)}k'
                  : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
