import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../core/services/follow_service.dart';
import '../../core/services/network_quality.dart';
import '../../widgets/embed_player.dart';
import '../../widgets/verified_badge.dart';
import '../../models/reel_model.dart';
import '../reels_repository.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import '../../app/app_theme.dart';
import '../../create/create_reel/create_reel_screen.dart';
import '../../gifts/gift_sheet.dart';

// ── Ads (ТАНҲО ИН 2 ХАТИ НАВ) ───────────────────────────────────────────────
import '../../core/ads/ads_manager.dart';
import '../../core/ads/rewarded_ad_flow.dart';
import '../../core/ui/app_icons.dart';

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
      reels = await _repo.fetchReels(
          page: 1, smart: !_friendsFilter, friends: _friendsFilter);
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
      final more = await _repo.fetchReels(
          page: _page + 1, smart: !_friendsFilter, friends: _friendsFilter);
      if (more.isNotEmpty) {
        reels = [...reels, ...more];
        _page++;
      }
    } catch (_) {}
    loadingMore = false;
    notifyListeners();
  }

  void toggleLike(String id) {
    bool nowLiked = false;
    reels = reels.map((r) {
      if (r.id != id) return r;
      final liked = !r.isLiked;
      nowLiked = liked;
      return r.copyWith(
          isLiked: liked, likesCount: r.likesCount + (liked ? 1 : -1));
    }).toList();
    if (nowLiked) {
      AnalyticsService.instance.logEvent(AnalyticsEvents.reelLike,
          params: {'reelId': id});
    }
    notifyListeners();
    _repo.likeReel(id).then((res) {
      if (res == null) return;
      reels = reels.map((r) {
        if (r.id != id) return r;
        return r.copyWith(
            isLiked: res['liked'] ?? r.isLiked,
            likesCount: res['likesCount'] ?? r.likesCount);
      }).toList();
      notifyListeners();
    });
  }

  void toggleSave(String id) {
    bool nowSaved = false;
    reels = reels.map((r) {
      if (r.id != id) return r;
      nowSaved = !r.isSaved;
      return r.copyWith(isSaved: nowSaved);
    }).toList();
    if (nowSaved) {
      AnalyticsService.instance.logEvent(AnalyticsEvents.reelSave,
          params: {'reelId': id});
    }
    notifyListeners();
    _repo.saveReel(id);
  }

  void toggleMute() {
    isMuted = !isMuted;
    notifyListeners();
  }

  void toggleFilter() {
    _friendsFilter = !_friendsFilter;
    notifyListeners();
    load(); // филтр иваз шуд → лента аз нав бор мешавад
  }

  void trackWatch({
    required String reelId,
    required int watchMs,
    required int durationMs,
  }) {
    _repo.trackWatchTime(
        reelId: reelId, watchMs: watchMs, durationMs: durationMs);
    AnalyticsService.instance.logEvent(AnalyticsEvents.reelView,
        params: {'reelId': reelId, 'watchMs': watchMs});
  }

  void markNotInterested(String id) {
    _repo.markNotInterested(id);
    reels = reels.where((r) => r.id != id).toList();
    notifyListeners();
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
  bool _initialPreloadDone = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // ── АД: инициализация (1 хати нав) ──────────────────────
    AdsManager.instance.init();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final ctrl in _preloaded.values) {
      ctrl.dispose();
    }
    _preloaded.clear();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // Интихоби сохтани reel: аз галерея ё аз силка (Aparat/YouTube).
  void _showReelCreateOptions(_ReelsVM vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(AppIcons.video_library_outlined, color: Colors.white),
            title: const Text('Аз галерея', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CreateReelScreen()))
                  .then((ok) { if (ok == true && mounted) vm.load(); });
            }),
          ListTile(
            leading: const Icon(AppIcons.link_rounded, color: Colors.white),
            title: const Text('Аз силка (Aparat/YouTube)',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Силкаи видеоро гузоред',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () { Navigator.pop(context); _createFromLink(vm); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _createFromLink(_ReelsVM vm) async {
    final linkCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Reel аз силка', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: linkCtrl, autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'https://www.aparat.com/v/...',
              hintStyle: TextStyle(color: Colors.white30))),
          const SizedBox(height: 10),
          TextField(controller: capCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Тавсиф (ихтиёрӣ)',
              hintStyle: TextStyle(color: Colors.white30))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Нашр', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    final link = linkCtrl.text.trim();
    final cap = capCtrl.text.trim();
    linkCtrl.dispose(); capCtrl.dispose();
    if (ok != true || link.isEmpty) return;
    if (!EmbedUtils.isEmbed(link)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Танҳо силкаи Aparat/YouTube қабул мешавад')));
      return;
    }
    try {
      await ApiClient.instance.post('/reels/', body: {
        'videoUrl': link, 'caption': cap,
      });
      if (mounted) {
        vm.load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reel илова шуд ✓'), backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Хато ҳангоми нашр')));
    }
  }

  void _onPageChanged(int i, _ReelsVM vm) {
    setState(() => _currentPage = i);
    if (i >= vm.reels.length - 3) vm.loadMore();
    _preloadAhead(i, vm);
    _disposeOld(i);
    // ── АД: ҳар 5 рилс interstitial нишон медиҳад (1 хати нав) ─
    AdsManager.instance.onReelSwiped();
  }

  void _preloadAhead(int current, _ReelsVM vm) {
    for (int j = current + 1; j <= current + 3; j++) {
      if (j >= vm.reels.length) break;
      if (_preloaded.containsKey(j)) continue;
      final reel = vm.reels[j];
      if (EmbedUtils.isEmbed(reel.videoUrl)) continue;
      final url = NetworkQuality.pick(reel.videoUrl, reel.videoUrlLow);
      if (url.isEmpty) continue;
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _preloaded[j] = ctrl;
      ctrl.initialize().then((_) {
        ctrl.setLooping(true);
        ctrl.setVolume(0);
        ctrl.play();
        ctrl.pause();
      });
    }
  }

  void _disposeOld(int current) {
    final toRemove =
        _preloaded.keys.where((k) => (k - current).abs() > 3).toList();
    for (final k in toRemove) {
      _preloaded[k]?.dispose();
      _preloaded.remove(k);
    }
  }

  void _preloadFirst(_ReelsVM vm) {
    if (vm.reels.isEmpty) return;
    final reel = vm.reels[0];
    if (EmbedUtils.isEmbed(reel.videoUrl)) return;
    if (_preloaded.containsKey(0)) return;
    final url = NetworkQuality.pick(reel.videoUrl, reel.videoUrlLow);
    if (url.isEmpty) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _preloaded[0] = ctrl;
    ctrl.initialize().then((_) {
      ctrl.setLooping(true);
      ctrl.setVolume(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_ReelsVM>();

    if (!_initialPreloadDone && vm.reels.isNotEmpty) {
      _initialPreloadDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadFirst(vm);
        _preloadAhead(0, vm);
      });
    }

    if (vm.loading && vm.reels.isEmpty) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: _ReelsSkeleton());
    }

    if (vm.reels.isEmpty) {
      return Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      Color(0xFF833AB4),
                      Color(0xFFE1306C),
                      Color(0xFFF77737)
                    ])),
                child: const Icon(AppIcons.video_collection_outlined,
                    color: Colors.white, size: 38)),
            const SizedBox(height: 20),
            const Text('Рилсҳо нест',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (vm.error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(vm.error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center))
            else
              const Text('Аввалин Рилс-ро шумо гузоред!',
                  style: TextStyle(color: Colors.white38, fontSize: 15)),
            const SizedBox(height: 28),
            GestureDetector(
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateReelScreen()))
                    .then((ok) {
                  if (ok == true && context.mounted) vm.load();
                }),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF833AB4),
                          Color(0xFFE1306C),
                          Color(0xFFF77737)
                        ]),
                        borderRadius: BorderRadius.circular(24)),
                    child: const Text('+ Рилс гузоред',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)))),
            const SizedBox(height: 12),
            TextButton(
                onPressed: vm.load,
                child: const Text('Боз кӯшиш кунед',
                    style: TextStyle(color: Colors.white38))),
          ])));
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.black54,
        onRefresh: () async {
          _currentPage = 0;
          _initialPreloadDone = false;
          for (final ctrl in _preloaded.values) ctrl.dispose();
          _preloaded.clear();
          await vm.load();
          if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
        },
        child: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        itemCount: vm.reels.length,
        onPageChanged: (i) => _onPageChanged(i, vm),
        itemBuilder: (_, i) => _ReelItem(
          key: ValueKey(vm.reels[i].id),
          reel: vm.reels[i],
          isActive: i == _currentPage && widget.isActive,
          isMuted: vm.isMuted,
          friendsFilter: vm.friendsFilter,
          preloadCtrl: _preloaded[i],
          onLike: () => vm.toggleLike(vm.reels[i].id),
          onSave: () => vm.toggleSave(vm.reels[i].id),
          onMuteToggle: vm.toggleMute,
          onToggleFilter: vm.toggleFilter,
          onAddReel: () => _showReelCreateOptions(vm),
          onDelete: () => vm.markNotInterested(vm.reels[i].id),
          onNotInterested: () {
            vm.markNotInterested(vm.reels[i].id);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    const Text('Рилс пинҳон шуд. Алгоритм навшуд.'),
                backgroundColor: Colors.grey[800],
                duration: const Duration(seconds: 2)));
          },
          onWatchTime: (watchMs, durationMs) => vm.trackWatch(
              reelId: vm.reels[i].id,
              watchMs: watchMs,
              durationMs: durationMs),
          // ── АД: rewarded download (1 хати нав) ─────────────
          onDownload: () => showRewardedAdFlow(
            context,
            rewardType: RewardType.videoDownload,
          ),
        ),
      ),
      ),
    );
  }
}

// ── Reels loading skeleton (shimmer) ─────────────────────────────────
class _ReelsSkeleton extends StatelessWidget {
  const _ReelsSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withOpacity(0.4),
      child: Stack(fit: StackFit.expand, children: [
        Container(color: base),
        // Right action rail placeholders
        Positioned(
          right: 14,
          bottom: bottom + size.height * 0.12,
          child: Column(mainAxisSize: MainAxisSize.min, children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )),
        ),
        // Bottom caption placeholders
        Positioned(
          left: 14, right: 90, bottom: bottom + 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 140, height: 14,
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 10),
              Container(width: double.infinity, height: 12,
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(width: 180, height: 12,
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(6))),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final bool isMuted;
  final bool friendsFilter;
  final VideoPlayerController? preloadCtrl;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onMuteToggle;
  final VoidCallback onToggleFilter;
  final VoidCallback onAddReel;
  final VoidCallback onDelete;
  final VoidCallback onNotInterested;
  final void Function(int watchMs, int durationMs) onWatchTime;
  final Future<bool> Function() onDownload; // ← НАВ

  const _ReelItem({
    super.key,
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.friendsFilter,
    this.preloadCtrl,
    required this.onLike,
    required this.onSave,
    required this.onMuteToggle,
    required this.onToggleFilter,
    required this.onAddReel,
    required this.onDelete,
    required this.onNotInterested,
    required this.onWatchTime,
    required this.onDownload, // ← НАВ
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _paused = false;
  bool _showHeart = false;
  bool _saved = false;
  bool _following = false;
  bool _captionExpanded = false;
  bool _isBuffering = false;
  bool _downloading = false; // ← НАВ
  late bool _hideLikes;      // ҳолати маҳаллӣ (то дарҳол нав шавад)
  late bool _commentsOff;    // ҳолати маҳаллӣ

  DateTime? _watchStart;
  int _totalWatchMs = 0;

  bool? _hasStory;
  bool _storyViewed = false;

  bool get _isOwner {
    final myId = UserSession.userId?.trim() ?? '';
    return myId.isNotEmpty && myId == widget.reel.user.id.trim();
  }

  @override
  void initState() {
    super.initState();
    _saved = widget.reel.isSaved;
    _hideLikes   = widget.reel.hideLikes;
    _commentsOff = widget.reel.commentsDisabled;
    _following = widget.reel.user.isFollowing; // агар аллакай пайравӣ кунӣ, тугма намебарояд
    FollowService.instance.prime(widget.reel.user.id, widget.reel.user.isFollowing);
    _initVideo();
    _loadStoryStatus();
  }

  Future<void> _loadStoryStatus() async {
    try {
      final res = await ApiClient.instance
          .get('/stories', query: {'userId': widget.reel.user.id});
      if (res.statusCode < 400 && mounted) {
        final body = jsonDecode(res.body);
        final List list =
            body is List ? body : (body['stories'] ?? body['data'] ?? []);
        setState(() {
          _hasStory = list.isNotEmpty;
          _storyViewed =
              list.isNotEmpty && list.every((s) => s['viewed'] == true);
        });
      }
    } catch (_) {}
  }

  // Видеои берунӣ (Aparat/YouTube) — на файли мустақим
  bool get _isEmbed => EmbedUtils.isEmbed(widget.reel.videoUrl);

  void _initVideo() {
    if (widget.reel.videoUrl.isEmpty) return;
    if (_isEmbed) return;
    if (widget.preloadCtrl != null) {
      _ctrl = widget.preloadCtrl;
      if (_ctrl!.value.isInitialized) {
        _ctrl!.setLooping(true);
        _ctrl!.setVolume(widget.isMuted ? 0.0 : 1.0);
        if (widget.isActive) {
          _ctrl!.play();
          _startWatchTimer();
        }
        setState(() => _initialized = true);
        _addBufferListener();
      } else {
        _ctrl!.initialize().then((_) {
          if (!mounted) return;
          _ctrl!.setLooping(true);
          _ctrl!.setVolume(widget.isMuted ? 0.0 : 1.0);
          if (widget.isActive) {
            _ctrl!.play();
            _startWatchTimer();
          }
          if (mounted) setState(() => _initialized = true);
          _addBufferListener();
        });
      }
      return;
    }
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(
        NetworkQuality.pick(widget.reel.videoUrl, widget.reel.videoUrlLow)))
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl!.setLooping(true);
        _ctrl!.setVolume(widget.isMuted ? 0.0 : 1.0);
        if (widget.isActive) {
          _ctrl!.play();
          _startWatchTimer();
        }
        if (mounted) setState(() => _initialized = true);
        _addBufferListener();
      });
  }

  void _addBufferListener() {
    _ctrl?.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (!mounted || _ctrl == null) return;
    final buffering = _ctrl!.value.isBuffering;
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
    }
  }

  void _startWatchTimer() {
    _watchStart = DateTime.now();
  }

  void _stopWatchTimer() {
    if (_watchStart == null) return;
    _totalWatchMs +=
        DateTime.now().difference(_watchStart!).inMilliseconds;
    _watchStart = null;
  }

  void _sendWatchTime() {
    _stopWatchTimer();
    if (_totalWatchMs <= 0 || !_initialized || _ctrl == null) return;
    final duration = _ctrl!.value.duration.inMilliseconds;
    if (duration <= 0) return;
    widget.onWatchTime(_totalWatchMs, duration);
  }

  @override
  void deactivate() {
    _stopWatchTimer();
    _ctrl?.pause();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (widget.isActive && _initialized) {
      _ctrl?.play();
      _startWatchTimer();
    }
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isMuted != old.isMuted && _ctrl != null) {
      _ctrl!.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.isActive && !old.isActive) {
      _ctrl?.setVolume(widget.isMuted ? 0.0 : 1.0);
      _ctrl?.play();
      _startWatchTimer();
    } else if (!widget.isActive && old.isActive) {
      _sendWatchTime();
      _ctrl?.pause();
    }
  }

  @override
  void dispose() {
    _sendWatchTime();
    _ctrl?.removeListener(_onVideoUpdate);
    if (widget.preloadCtrl == null || widget.preloadCtrl != _ctrl) {
      _ctrl?.dispose();
    }
    super.dispose();
  }

  void _togglePause() {
    if (_ctrl == null) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _ctrl!.pause();
      _stopWatchTimer();
    } else {
      _ctrl!.play();
      _startWatchTimer();
    }
  }

  void _doubleTapLike() {
    if (!widget.reel.isLiked) widget.onLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openProfile() => Navigator.pushNamed(
      context, '/user-profile',
      arguments: widget.reel.user.id);

  // ── АД: Download handler ─────────────────────────────────────────────────
  Future<void> _handleDownload() async {
    setState(() => _downloading = true);
    _ctrl?.pause();
    try {
      await widget.onDownload();
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
        if (!_paused) _ctrl?.play();
      }
    }
  }

  void _showOwnerMenu() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        _menuItem(AppIcons.edit_outlined, 'Таҳрир кардан',
            () {
          Navigator.pop(context);
          _editCaption();
        }),
        _menuItem(AppIcons.bar_chart_rounded, 'Омор (Статистика)',
            () {
          Navigator.pop(context);
          _showStats();
        }),
        _menuItem(AppIcons.alternate_email, 'Илова кардани зикр',
            () {
          Navigator.pop(context);
          _addMention();
        }),
        _menuItem(
            _hideLikes ? AppIcons.visibility_rounded : AppIcons.visibility_off_outlined,
            _hideLikes ? 'Нишон додани лайкҳо' : 'Пинҳон кардани лайкҳо',
            () async {
          Navigator.pop(context);
          final target = !_hideLikes;
          setState(() => _hideLikes = target);
          try {
            final res = await ApiClient.instance
                .post('/reels/${widget.reel.id}/hide-likes');
            if (res.statusCode < 400) {
              final b = jsonDecode(res.body);
              if (b['hideLikes'] is bool && mounted) {
                setState(() => _hideLikes = b['hideLikes'] as bool);
              }
            } else if (mounted) {
              setState(() => _hideLikes = !target);
            }
          } catch (_) { if (mounted) setState(() => _hideLikes = !target); }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_hideLikes
                    ? 'Лайкҳо пинҳон шуданд ✓'
                    : 'Лайкҳо намоён шуданд ✓'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2)));
          }
          if (!_paused) _ctrl?.play();
        }),
        _menuItem(
            _commentsOff ? AppIcons.mode_comment_rounded : AppIcons.mode_comment_outlined,
            _commentsOff ? 'Фаъол кардани шарҳҳо' : 'Хомӯш кардани шарҳҳо',
            () async {
          Navigator.pop(context);
          final target = !_commentsOff;
          setState(() => _commentsOff = target);
          try {
            final res = await ApiClient.instance
                .post('/reels/${widget.reel.id}/toggle-comments');
            if (res.statusCode < 400) {
              final b = jsonDecode(res.body);
              if (b['commentsOff'] is bool && mounted) {
                setState(() => _commentsOff = b['commentsOff'] as bool);
              }
            } else if (mounted) {
              setState(() => _commentsOff = !target);
            }
          } catch (_) { if (mounted) setState(() => _commentsOff = !target); }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_commentsOff
                    ? 'Шарҳҳо хомӯш шуданд ✓'
                    : 'Шарҳҳо фаъол шуданд ✓'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2)));
          }
          if (!_paused) _ctrl?.play();
        }),
        _menuItem(AppIcons.delete_outline_rounded, 'Нест кардан', () {
          Navigator.pop(context);
          _deleteReel();
        }, color: Colors.redAccent),
        const SizedBox(height: 8),
      ])),
    ).then((_) {
      if (!_paused) _ctrl?.play();
    });
  }

  void _showOtherMenu() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        _menuItem(_saved ? AppIcons.bookmark : AppIcons.bookmark_border_rounded,
            _saved ? 'Захира шуд' : 'Захира кардан', () {
          Navigator.pop(context);
          setState(() => _saved = !_saved);
          widget.onSave();
        }),
        _menuItem(AppIcons.thumb_up_outlined, 'Ҷолиб аст', () {
          Navigator.pop(context);
          _markInterest(true);
        }),
        _menuItem(AppIcons.thumb_down_outlined, 'Ҷолиб нест', () {
          Navigator.pop(context);
          widget.onNotInterested();
        }),
        _menuItem(AppIcons.info_outline_rounded, 'Чаро ин рилсро мебинед', () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ин рилс аз рӯи завқ ва фаъолияти шумо нишон дода шуд'),
              duration: Duration(seconds: 3)));
        }),
        _menuItem(AppIcons.flag_outlined, 'Шикоят кардан', () {
          Navigator.pop(context);
          _report();
        }, color: Colors.redAccent),
        _menuItem(AppIcons.person_outline_rounded, 'Дидани профил', () {
          Navigator.pop(context);
          _openProfile();
        }),
        // ── АД: Download menu item ───────────────────────────
        _menuItem(
          _downloading ? AppIcons.hourglass_bottom_rounded : AppIcons.download_rounded,
          'Зеркашии видео',
          _downloading ? () {} : () {
            Navigator.pop(context);
            _handleDownload();
          },
          color: AppColors.neonBlue,
        ),
        const SizedBox(height: 8),
      ])),
    ).then((_) {
      if (!_paused) _ctrl?.play();
    });
  }

  Widget _handle() => Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(2)));

  Widget _menuItem(IconData icon, String label, VoidCallback onTap,
          {Color? color}) =>
      ListTile(
          leading: Icon(icon, color: color ?? Colors.white, size: 22),
          title: Text(label,
              style: TextStyle(color: color ?? Colors.white, fontSize: 15)),
          onTap: onTap);

  Future<void> _editCaption() async {
    final ctrl = TextEditingController(text: widget.reel.caption);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Таҳрир кардан',
            style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                hintText: 'Тавсиф...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF111111),
                border: OutlineInputBorder(
                    borderSide: BorderSide.none))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Захира',
                  style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    final trimmed = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) {
      if (!_paused) _ctrl?.play();
      return;
    }
    await ApiClient.instance.put('/reels/${widget.reel.id}/caption',
        body: {'caption': trimmed});
    if (!_paused && mounted) _ctrl?.play();
  }

  Future<void> _addMention() async {
    final ctrl = TextEditingController();
    List results = [];
    bool searching = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            _handle(),
            const Text('Зикр кардан',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: 'Ном ё username...',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon:
                        Icon(AppIcons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none)),
                onChanged: (q) async {
                  if (q.trim().isEmpty) {
                    setS(() => results = []);
                    return;
                  }
                  setS(() => searching = true);
                  try {
                    final res = await ApiClient.instance
                        .get('/search', query: {'q': q});
                    if (res.statusCode < 400) {
                      final b = jsonDecode(res.body);
                      setS(() {
                        results = b['users'] ?? [];
                        searching = false;
                      });
                    }
                  } catch (_) {
                    setS(() => searching = false);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: searching
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white30))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final u = results[i];
                        return ListTile(
                            leading: CircleAvatar(
                                backgroundImage:
                                    (u['avatar']?.isNotEmpty == true)
                                        ? CachedNetworkImageProvider(u['avatar'], maxWidth: 80)
                                        : null,
                                child: (u['avatar']?.isEmpty != false)
                                    ? const Icon(AppIcons.person)
                                    : null),
                            title: Text('@${u['username']}',
                                style: const TextStyle(
                                    color: Colors.white)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final uname = (u['username'] ?? '').toString();
                              if (uname.isEmpty) return;
                              final base = widget.reel.caption.trim();
                              final newCaption =
                                  base.isEmpty ? '@$uname' : '$base @$uname';
                              try {
                                await ApiClient.instance.put(
                                    '/reels/${widget.reel.id}/caption',
                                    body: {'caption': newCaption});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('@$uname зикр шуд'),
                                          duration:
                                              const Duration(seconds: 2)));
                                }
                              } catch (_) {}
                            });
                      }),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (!_paused && mounted) _ctrl?.play();
  }

  Future<void> _showStats() async {
    final repo = ReelsRepository(ApiClient.instance);
    final stats = await repo.fetchStats(widget.reel.id);
    if (!mounted) return;
    final s = stats ?? {};
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Омор',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _statRow('👁 Тамошошуд',
              '${s['views'] ?? widget.reel.viewsCount}'),
          _statRow(
              '❤ Лайк', '${s['likes'] ?? widget.reel.likesCount}'),
          _statRow('💬 Шарҳ',
              '${s['comments'] ?? widget.reel.commentsCount}'),
          _statRow('🔖 Захира', '${s['saves'] ?? 0}'),
          _statRow('📤 Мубодила',
              '${s['shares'] ?? widget.reel.sharesCount}'),
          _statRow(
              '⏱ Миёнаи тамошо',
              '${s['avgWatchMs'] != null ? (s['avgWatchMs'] / 1000).toStringAsFixed(1) + " сон" : "—"}'),
        ]),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!_paused) _ctrl?.play();
              },
              child: const Text('Пӯшидан',
                  style: TextStyle(color: AppColors.neonBlue)))
        ],
      ),
    );
  }

  Widget _statRow(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14)),
            Text(v,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15))
          ]));

  Future<void> _deleteReel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Нест кардан?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Рилс тамоман нест мешавад.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Нест кун',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) {
      if (!_paused) _ctrl?.play();
      return;
    }
    await ApiClient.instance.delete('/reels/${widget.reel.id}');
    widget.onDelete();
  }

  Future<void> _markInterest(bool interested) async {
    await ApiClient.instance.post(
        '/reels/${widget.reel.id}/${interested ? 'interest' : 'not_interest'}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            interested ? 'Алгоритм навшуд ✓' : 'Рилс пинҳон шуд'),
        backgroundColor:
            interested ? Colors.green : Colors.grey[800],
        duration: const Duration(seconds: 2)));
    if (!_paused) _ctrl?.play();
  }

  Future<void> _report() async {
    final reasons = [
      {'key': 'spam', 'label': 'Спам'},
      {'key': 'violence', 'label': 'Зӯроварӣ'},
      {'key': 'adult', 'label': 'Мӯҳтавои калонсолон'},
      {'key': 'hate', 'label': 'Нафрат'},
      {'key': 'other', 'label': 'Дигар'},
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Шикоят кардан',
            style: TextStyle(color: Colors.white)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => ListTile(
                    title: Text(r['label']!,
                        style:
                            const TextStyle(color: Colors.white)),
                    onTap: () =>
                        Navigator.pop(context, r['key'])))
                .toList()),
      ),
    );
    if (reason == null) {
      if (!_paused) _ctrl?.play();
      return;
    }
    await ApiClient.instance
        .post('/reels/${widget.reel.id}/report', body: {'reason': reason});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Шикоят фиристода шуд. Раҳмат!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2)));
    }
    if (!_paused) _ctrl?.play();
  }

  void _openComments() {
    // Шарҳҳо хомӯшанд ва бинанда соҳиб нест → пайғоми маҳдудият.
    if (_commentsOff && !_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Шарҳҳо барои ин Reel хомӯш карда шудаанд'),
          duration: Duration(seconds: 2)));
      return;
    }
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: _ReelComments(
            reelId: widget.reel.id,
            authorId: widget.reel.user.id,
            authorName: widget.reel.user.username,
          )),
    ).then((_) {
      if (!_paused && mounted) _ctrl?.play();
    });
  }

  void _share() {
    AnalyticsService.instance.logEvent(AnalyticsEvents.reelShare,
        params: {'reelId': widget.reel.id});
    final url =
        'https://mahmadmurodov-raonson.hf.space/reels/${widget.reel.id}';
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) =>
          SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        const Text('Мубодила',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 8),
        ListTile(
            leading: const CircleAvatar(
                backgroundColor: AppColors.neonBlue,
                child: Icon(AppIcons.send_outlined,
                    color: Colors.white, size: 18)),
            title: const Text('Дар паём фиристодан',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Ба дӯстон бифиристед',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _sendToDM(url);
            }),
        ListTile(
            leading: const CircleAvatar(
                backgroundColor: Color(0xFF833AB4),
                child: Icon(AppIcons.add_circle_outline,
                    color: Colors.white, size: 18)),
            title: const Text('Ба история илова кун',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await ApiClient.instance.post('/stories/', body: {
                  'mediaUrl': widget.reel.videoUrl,
                  'mediaType': 'video',
                  'caption': widget.reel.caption,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ба история илова шуд ✓'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2)));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Хато ҳангоми илова'),
                      duration: Duration(seconds: 2)));
                }
              }
            }),
        ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.white12,
                child: Icon(AppIcons.link, color: Colors.white, size: 18)),
            title: const Text('Линкро нусха кун',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Линк нусха шуд ✓'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2)));
            }),
        ListTile(
            leading: const CircleAvatar(
                backgroundColor: Colors.white12,
                child: Icon(AppIcons.share_outlined,
                    color: Colors.white, size: 18)),
            title: const Text('Дигар барномаҳо',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Share.share(url);
            }),
        const SizedBox(height: 8),
      ])),
    ).then((_) {
      if (!_paused && mounted) _ctrl?.play();
    });
  }

  Future<void> _sendToDM(String url) async {
    Navigator.pushNamed(context, '/messages',
        arguments: {'shareUrl': url});
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    }
    return n > 0 ? '$n' : '';
  }

  List<InlineSpan> _buildCaptionSpans(String text) {
    final spans = <InlineSpan>[];
    final words = text.split(' ');
    for (final word in words) {
      if (word.startsWith('#') && word.length > 1) {
        final tag = word.replaceAll(RegExp(r'[^\w]'), '');
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/hashtag',
                  arguments: tag),
              child: Text('$word ',
                  style: const TextStyle(
                      color: AppColors.neonBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black)
                      ]))),
        ));
      } else if (word.startsWith('@') && word.length > 1) {
        final username =
            word.substring(1).replaceAll(RegExp(r'[^\w]'), '');
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, '/profile-by-username',
                  arguments: username),
              child: Text('$word ',
                  style: const TextStyle(
                      color: AppColors.neonBlue,
                      fontSize: 14,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black)
                      ]))),
        ));
      } else {
        spans.add(TextSpan(
            text: '$word ',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(blurRadius: 4, color: Colors.black)
                ])));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final top = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: _togglePause,
      onDoubleTap: _doubleTapLike,
      child: Stack(fit: StackFit.expand, children: [
        // Фони сиёҳ — кафолат, ки ягон навори хокистарӣ намонад (мисли Instagram)
        const ColoredBox(color: Colors.black),
        if (_isEmbed)
          // Видеои берунӣ (Aparat/YouTube) дар WebView
          EmbedPlayer(url: widget.reel.videoUrl)
        else if (_initialized && _ctrl != null)
          FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                  width: _ctrl!.value.size.width,
                  height: _ctrl!.value.size.height,
                  child: VideoPlayer(_ctrl!)))
        else if (reel.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
              imageUrl: reel.thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, __, ___) =>
                  Container(color: AppColors.bg))
        else
          Container(color: AppColors.bg),

        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
              Color(0x66000000),
              Colors.transparent,
              Color(0x33000000),
              Color(0xEE000000)
            ],
                    stops: [
              0,
              0.35,
              0.65,
              1
            ]))),

        if (_isBuffering && !_paused)
          const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation(Colors.white70))),

        if (_paused && !_isBuffering)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Mute button above play (Instagram style)
              GestureDetector(
                onTap: widget.onMuteToggle,
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: Icon(
                      widget.isMuted
                          ? AppIcons.volume_off_rounded
                          : AppIcons.volume_up_rounded,
                      color: Colors.white, size: 20))),
              const SizedBox(height: 10),
              // Play button
              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]),
                padding: const EdgeInsets.all(16),
                child: const Icon(AppIcons.play_arrow_rounded,
                    color: Colors.white, size: 48)),
            ])),

        if (_showHeart) const Center(child: _HeartBurst()),

        if (_initialized && _ctrl != null)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                  valueListenable: _ctrl!,
                  builder: (_, val, __) {
                    final pos = val.position.inMilliseconds;
                    final dur = val.duration.inMilliseconds;
                    return LinearProgressIndicator(
                        value: dur > 0 ? pos / dur : 0,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 2);
                  })),

        Positioned(
            top: top + 12,
            left: 0,
            right: 0,
            child: Stack(alignment: Alignment.center, children: [
              // ── CENTER: Рилсҳо | Дӯстон (точно по середине) ──
              GestureDetector(
                  onTap: widget.onToggleFilter,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        widget.friendsFilter ? 'Дӯстон' : 'Рилсҳо',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
                    const SizedBox(width: 6),
                    const Text('|',
                        style: TextStyle(color: Colors.white54, fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                        widget.friendsFilter ? 'Рилсҳо' : 'Дӯстон',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
                    const SizedBox(width: 4),
                    const Icon(AppIcons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 18),
                  ])),
              // ── RIGHT: Upload SVG icon ────────────────────────
              Positioned(
                  right: 16,
                  child: GestureDetector(
                      onTap: widget.onAddReel,
                      child: SvgPicture.asset('assets/icons/upload.svg',
                          width: 26, height: 26,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn)))),
            ])),

        Positioned(
            right: 10,
            bottom: bottom + size.height * 0.10,
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              _LikeBtn(
                  isLiked: reel.isLiked,
                  // Лайкҳо пинҳонанд ва бинанда соҳиб нест → калима, на рақам.
                  count: (_hideLikes && !_isOwner)
                      ? 'Лайкҳо'
                      : _fmt(reel.likesCount),
                  onTap: widget.onLike),
              const SizedBox(height: 22),
              // Шарҳҳо хомӯшанд → icon-и коммент нопадид мешавад (мисли Instagram).
              if (!_commentsOff) ...[
                _ReelStableBtn(
                    svgPath: 'assets/icons/comment.svg',
                    count: _fmt(reel.commentsCount),
                    onTap: _openComments),
                const SizedBox(height: 22),
              ],
              _ReelStableBtn(
                  svgPath: 'assets/icons/share.svg',
                  count: '',
                  onTap: _share),
              const SizedBox(height: 22),
              _ReelStableBtn(
                  svgPath: 'assets/icons/save.svg',
                  activeSvgPath: 'assets/icons/save_filled.svg',
                  isActive: _saved,
                  activeColor: Colors.white,
                  count: '',
                  onTap: () {
                    setState(() => _saved = !_saved);
                    widget.onSave();
                  }),
              const SizedBox(height: 22),
              GestureDetector(
                  onTap: _isOwner ? _showOwnerMenu : _showOtherMenu,
                  child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(AppIcons.more_vert_rounded,
                          color: Colors.white,
                          size: 28,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54)
                          ]))),
              const SizedBox(height: 16),
              _SpinningDisc(
                  avatar: reel.user.avatar,
                  isPlaying: _initialized && !_paused),
            ])),

        Positioned(
            left: 14,
            right: 90,
            bottom: bottom + 24,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    GestureDetector(
                        onTap: _openProfile,
                        child: _AvatarWithStoryRing(
                            avatarUrl: reel.user.avatar,
                            hasStory: _hasStory,
                            storyViewed: _storyViewed)),
                    const SizedBox(width: 10),
                    Flexible(
                        child: GestureDetector(
                            onTap: _openProfile,
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                      child: Text(reel.user.username,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 15,
                                              shadows: [
                                                Shadow(
                                                    blurRadius: 4,
                                                    color: Colors.black)
                                              ]),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis)),
                                  if (reel.user.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const VerifiedBadge(size: 14, color: Colors.white)
                                  ],
                                ]))),
                    if (!_isOwner)
                      ValueListenableBuilder<Map<String, bool>>(
                        valueListenable: FollowService.instance.states,
                        builder: (_, __, ___) {
                          final following = FollowService.instance
                              .resolve(reel.user.id, _following);
                          if (following) return const SizedBox.shrink();
                          return Row(mainAxisSize: MainAxisSize.min, children: [
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => FollowService.instance
                                  .toggle(reel.user.id, false),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white, width: 1.2),
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                  child: const Text('Пайравӣ кунед',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          shadows: [
                                            Shadow(
                                                blurRadius: 4,
                                                color: Colors.black)
                                          ]))),
                            ),
                          ]);
                        },
                      ),
                  ]),
                  if (reel.caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _CaptionWidget(
                        caption: reel.caption,
                        spans: _buildCaptionSpans(reel.caption),
                        expanded: _captionExpanded,
                        onToggle: () => setState(
                            () => _captionExpanded = !_captionExpanded)),
                  ],
                  const SizedBox(height: 10),
                  _AudioBar(
                      title: reel.audioTitle,
                      artist: reel.audioArtist,
                      avatar: reel.user.avatar,
                      isPlaying: _initialized && !_paused),
                ])),
      ]),
    );
  }
}

class _CaptionWidget extends StatelessWidget {
  final String caption;
  final List<InlineSpan> spans;
  final bool expanded;
  final VoidCallback onToggle;
  static const int _maxLines = 2;

  const _CaptionWidget(
      {required this.caption,
      required this.spans,
      required this.expanded,
      required this.onToggle});

  bool _needsTruncation(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(
          text: caption,
          style:
              const TextStyle(color: Colors.white, fontSize: 14)),
      maxLines: _maxLines,
      textDirection: TextDirection.ltr,
    )..layout(
        maxWidth: MediaQuery.of(context).size.width - 110);
    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final needsMore = _needsTruncation(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
              maxLines:
                  expanded ? null : (needsMore ? _maxLines : null),
              overflow: expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              text: TextSpan(children: spans)),
          if (needsMore)
            GestureDetector(
                onTap: onToggle,
                child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                        expanded ? 'камтар' : 'бештар',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)))),
        ]);
  }
}

class _AudioBar extends StatefulWidget {
  final String title, artist, avatar;
  final bool isPlaying;
  const _AudioBar(
      {required this.title,
      required this.artist,
      required this.avatar,
      required this.isPlaying});
  @override
  State<_AudioBar> createState() => _AudioBarState();
}

class _AudioBarState extends State<_AudioBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _scrollCtrl;
  late Animation<double> _scrollAnim;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _scrollAnim = Tween(begin: 0.0, end: 1.0).animate(_scrollCtrl);
    if (!widget.isPlaying) _scrollCtrl.stop();
  }

  @override
  void didUpdateWidget(_AudioBar old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _scrollCtrl.repeat();
    } else if (!widget.isPlaying && old.isPlaying) {
      _scrollCtrl.stop();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Музика → ном • хонанда; вагарна «Аудиои оригиналӣ» (мисли Instagram)
    final displayText = widget.title.trim().isEmpty
        ? 'Аудиои оригиналӣ'
        : (widget.artist.isNotEmpty
            ? '${widget.title} — ${widget.artist}'
            : widget.title);

    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(AppIcons.music_note_rounded,
          color: Colors.white,
          size: 15,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
      const SizedBox(width: 5),
      Flexible(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _scrollAnim,
            builder: (_, __) {
              final double dx = -(_scrollAnim.value * 0.5);
              return FractionalTranslation(
                translation: Offset(dx, 0.0),
                child: Text(
                  '$displayText   $displayText',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black)
                      ]),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class _LikeBtn extends StatefulWidget {
  final bool isLiked;
  final String count;
  final VoidCallback onTap;
  const _LikeBtn(
      {required this.isLiked,
      required this.count,
      required this.onTap});
  @override
  State<_LikeBtn> createState() => _LikeBtnState();
}

class _LikeBtnState extends State<_LikeBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.isLiked) _ctrl.forward(from: 0);
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 30,
              height: 30,
              child: SvgPicture.asset(
                  widget.isLiked
                      ? 'assets/icons/heart_filled.svg'
                      : 'assets/icons/heart.svg',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(
                      widget.isLiked ? Colors.red : Colors.white,
                      BlendMode.srcIn))),
          if (widget.count.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.count,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54)
                    ])),
          ],
        ]),
      ),
    );
  }
}

class _AvatarWithStoryRing extends StatelessWidget {
  final String avatarUrl;
  final bool? hasStory;
  final bool storyViewed;
  const _AvatarWithStoryRing(
      {required this.avatarUrl,
      required this.hasStory,
      required this.storyViewed});

  @override
  Widget build(BuildContext context) {
    if (hasStory == false) {
      return ClipOval(
          child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  width: 42, height: 42, color: AppColors.card),
              errorWidget: (_, __, ___) => Container(
                  width: 42,
                  height: 42,
                  color: AppColors.card,
                  child: const Icon(AppIcons.person,
                      color: Colors.white54, size: 22))));
    }
    final gradientColors = storyViewed
        ? [const Color(0xFF555555), const Color(0xFF444444)]
        : AppColors.storyGradient;
    return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasStory == true
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: hasStory == null ? Colors.transparent : null),
        padding: const EdgeInsets.all(2.5),
        child: Container(
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.black),
            padding: const EdgeInsets.all(1.5),
            child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.card),
                        errorWidget: (_, __, ___) => Container(
                            color: AppColors.card,
                            child: const Icon(AppIcons.person,
                                color: Colors.white54, size: 20)))
                    : Container(
                        color: AppColors.card,
                        child: const Icon(AppIcons.person,
                            color: Colors.white54, size: 20)))));
  }
}

class _ReelStableBtn extends StatelessWidget {
  final String svgPath, count;
  final String? activeSvgPath;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  const _ReelStableBtn(
      {required this.svgPath,
      this.activeSvgPath,
      this.isActive = false,
      this.activeColor = Colors.red,
      required this.count,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final path =
        (isActive && activeSvgPath != null) ? activeSvgPath! : svgPath;
    final color = isActive ? activeColor : Colors.white;
    return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 30,
              height: 30,
              child: SvgPicture.asset(path,
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  colorFilter:
                      ColorFilter.mode(color, BlendMode.srcIn))),
          if (count.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(count,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54)
                    ])),
          ],
        ]));
  }
}

class _SpinningDisc extends StatefulWidget {
  final String avatar;
  final double size;
  final bool isPlaying;
  const _SpinningDisc(
      {required this.avatar,
      this.size = 44,
      required this.isPlaying});
  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    if (widget.isPlaying) _spinCtrl.repeat();
  }

  @override
  void didUpdateWidget(_SpinningDisc old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _spinCtrl.repeat();
    } else if (!widget.isPlaying && old.isPlaying) {
      _spinCtrl.stop();
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size * 0.22;
    return RotationTransition(
      turns: _spinCtrl,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Colors.white30, width: 1.5),
            color: Colors.black45),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(r - 1),
            child: widget.avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.avatar,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                        AppIcons.music_note_rounded,
                        color: Colors.white54, size: 18))
                : const Icon(AppIcons.music_note_rounded,
                    color: Colors.white54, size: 18))));
  }
}

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
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700))
      ..forward();
    _scale = Tween(begin: 0.3, end: 1.4).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
              scale: _scale.value,
              child: const Icon(AppIcons.favorite,
                  color: Colors.white,
                  size: 120,
                  shadows: [
                    Shadow(blurRadius: 30, color: Colors.black54)
                  ]))));
}

class _ReelComments extends StatefulWidget {
  final String reelId;
  final String authorId;
  final String authorName;
  const _ReelComments({
    required this.reelId,
    this.authorId = '',
    this.authorName = '',
  });
  @override
  State<_ReelComments> createState() => _ReelCommentsState();
}

class _ReelCommentsState extends State<_ReelComments> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true, _sending = false;
  String? _replyToId;
  String? _replyToUsername;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ReelsRepository(ApiClient.instance);
      final list = await repo.fetchComments(widget.reelId);
      if (mounted) {
        setState(() {
          _comments = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final repo = ReelsRepository(ApiClient.instance);
    try {
      if (_replyToId != null) {
        await repo.replyComment(
            reelId: widget.reelId,
            commentId: _replyToId!,
            text: text);
      } else {
        await repo.addComment(reelId: widget.reelId, text: text);
      }
      _ctrl.clear();
      setState(() {
        _replyToId = null;
        _replyToUsername = null;
      });
      _load();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _likeComment(String commentId, int index) async {
    final repo = ReelsRepository(ApiClient.instance);
    final res = await repo.likeComment(
        reelId: widget.reelId, commentId: commentId);
    if (res != null && mounted) {
      setState(() {
        _comments[index] = {
          ..._comments[index],
          'liked': res['liked'] ?? false,
          'likesCount': res['likesCount'] ?? 0,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
      Text('Шарҳҳо (${_comments.length})',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
      const SizedBox(height: 4),
      const Divider(color: Colors.white10),
      Expanded(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.storyStart)))
            : _comments.isEmpty
                ? const Center(
                    child: Text('Аввалин бошед!',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 15)))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      final u = c['user'] as Map? ?? {};
                      final liked = c['liked'] ?? false;
                      final likesCount = c['likesCount'] ?? 0;
                      final id =
                          (c['_id'] ?? c['id'] ?? '').toString();
                      return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.card,
                                    backgroundImage:
                                        (u['avatar'] ?? '').isNotEmpty
                                            ? CachedNetworkImageProvider(u['avatar'], maxWidth: 72)
                                            : null,
                                    child: (u['avatar'] ?? '').isEmpty
                                        ? const Icon(AppIcons.person,
                                            color: Colors.white54,
                                            size: 18)
                                        : null),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(u['username'] ?? '',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Text(c['text'] ?? '',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _replyToId = id;
                                              _replyToUsername =
                                                  u['username']
                                                      ?.toString();
                                              _ctrl.text =
                                                  '@${u['username']} ';
                                            });
                                          },
                                          child: const Text('Ҷавоб',
                                              style: TextStyle(
                                                  color:
                                                      Colors.white38,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w500))),
                                    ])),
                                const SizedBox(width: 8),
                                GestureDetector(
                                    onTap: () =>
                                        _likeComment(id, i),
                                    child: Column(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Icon(
                                              liked
                                                  ? AppIcons.favorite
                                                  : Icons
                                                      .favorite_border_rounded,
                                              color: liked
                                                  ? Colors.red
                                                  : Colors.white38,
                                              size: 18),
                                          if (likesCount > 0) ...[
                                            const SizedBox(height: 2),
                                            Text('$likesCount',
                                                style: const TextStyle(
                                                    color:
                                                        Colors.white38,
                                                    fontSize: 11))
                                          ],
                                        ])),
                              ]));
                    }),
      ),
      if (_replyToUsername != null)
        Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            color: Colors.white10,
            child: Row(children: [
              Text('Ҷавоб ба @$_replyToUsername',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                  onTap: () => setState(() {
                        _replyToId = null;
                        _replyToUsername = null;
                        _ctrl.clear();
                      }),
                  child: const Icon(AppIcons.close,
                      color: Colors.white38, size: 16)),
            ])),
      // Emoji quick-reaction row (мисли Instagram)
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: ['❤️','🙌','🔥','👏','😢','😍','😮','😂']
              .map((e) => GestureDetector(
                    onTap: () {
                      final t = _ctrl.text;
                      _ctrl.text = t + e;
                      _ctrl.selection = TextSelection.collapsed(
                          offset: _ctrl.text.length);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Center(child: Text(e,
                          style: const TextStyle(fontSize: 24))),
                    ),
                  ))
              .toList(),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 12,
              bottom: 8,
              top: 4 +
                  MediaQuery.of(context).viewInsets.bottom / 2),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                        hintText: _replyToUsername != null
                            ? 'Ҷавоб ба @$_replyToUsername...'
                            : 'Шарҳ нависед...',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)))),
            // Тӯҳфа (gift)
            IconButton(
                icon: SvgPicture.asset('assets/icons/gift.svg',
                    width: 26, height: 26,
                    colorFilter: const ColorFilter.mode(
                        Colors.white70, BlendMode.srcIn)),
                onPressed: widget.authorId.isEmpty
                    ? null
                    : () => showGiftSheet(
                          context,
                          toUserId: widget.authorId,
                          authorName: widget.authorName,
                          targetType: 'reel',
                          targetId: widget.reelId,
                        )),
            GestureDetector(
                onTap: _send,
                child: _sending
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                AppColors.neonBlue)))
                    : const Icon(AppIcons.send_rounded,
                        color: AppColors.neonBlue, size: 28)),
          ]),
        ),
      ),
    ]);
  }
}
