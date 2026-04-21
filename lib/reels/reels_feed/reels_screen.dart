import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
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

  List<ReelModel> reels    = [];
  bool loading             = false;
  bool loadingMore         = false;
  int  _page               = 1;
  String? error;

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try {
      reels = await _repo.fetchReels(page: 1);
      _page = 1;
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
        id: r.id, videoUrl: r.videoUrl, caption: r.caption, user: r.user,
        commentsCount: r.commentsCount,
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
  int  _currentPage              = 0;
  bool _friendsFilter            = false;

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

    if (vm.loading && vm.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.storyStart))),
      );
    }

    if (vm.reels.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80,
            decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF77737)])),
            child: const Icon(Icons.video_collection_outlined,
                color: Colors.white, size: 38)),
          const SizedBox(height: 20),
          const Text('Рилсҳо нест', style: TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (vm.error != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(vm.error!, style: const TextStyle(
                  color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center))
          else
            const Text('Аввалин Рилс-ро шумо гузоред!',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateReelScreen()))
                .then((ok) { if (ok == true) context.read<_ReelsVM>().load(); }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF77737)]),
                borderRadius: BorderRadius.circular(24)),
              child: const Text('+ Рилс гузоред',
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
          onToggleFilter: () =>
              setState(() => _friendsFilter = !_friendsFilter),
          onAddReel: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateReelScreen()))
              .then((ok) { if (ok == true) vm.load(); }),
          onDelete: () {
            vm.reels = vm.reels.where((r) => r.id != vm.reels[i].id).toList();
            vm.notifyListeners();
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SINGLE REEL ITEM
// ══════════════════════════════════════════════════════════════════
class _ReelItem extends StatefulWidget {
  final ReelModel    reel;
  final bool         isActive;
  final bool         friendsFilter;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onToggleFilter;
  final VoidCallback onAddReel;
  final VoidCallback onDelete;

  const _ReelItem({
    required this.reel,
    required this.isActive,
    required this.friendsFilter,
    required this.onLike,
    required this.onSave,
    required this.onToggleFilter,
    required this.onAddReel,
    required this.onDelete,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _ctrl;
  bool _initialized  = false;
  bool _paused       = false;
  bool _showHeart    = false;
  bool _saved        = false;
  bool _following    = false;
  int  _retweetCount = 0;

  // Story ring state — аз backend load мешавад
  // null = маълум нест, true = story дорад, false = story надорад
  bool? _hasStory;
  bool  _storyViewed = false; // ҳамаи story-ҳо дида шудааст

  bool get _isOwner {
    final myId = UserSession.userId?.trim() ?? '';
    return myId.isNotEmpty && myId == widget.reel.user.id.trim();
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadStoryStatus();
  }

  // ── Story ring status — API-аз мегирем ──────────────────────────
  Future<void> _loadStoryStatus() async {
    try {
      final res = await ApiClient.instance
          .get('/stories', query: {'userId': widget.reel.user.id});
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body
            : (body['stories'] ?? body['data'] ?? []);
        if (mounted) {
          setState(() {
            _hasStory    = list.isNotEmpty;
            _storyViewed = list.isNotEmpty &&
                list.every((s) => s['viewed'] == true);
          });
        }
      }
    } catch (_) {}
  }

  void _initVideo() {
    if (widget.reel.videoUrl.isEmpty) return;
    _ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl!.setLooping(true);
        if (widget.isActive) { _ctrl!.setVolume(1.0); _ctrl!.play(); }
        setState(() => _initialized = true);
      });
  }

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
      _ctrl?.setVolume(1.0); _ctrl?.play();
      ApiClient.instance.post('/reels/${widget.reel.id}/view');
    } else if (!widget.isActive && old.isActive) {
      _ctrl?.pause();
    }
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

  // ── Профили корбар ────────────────────────────────────────────
  void _openProfile() {
    Navigator.pushNamed(context, '/user-profile',
        arguments: widget.reel.user.id);
  }

  // ── ⋮ МЕНЮ — соҳиб (Тоҷикӣ) ─────────────────────────────────
  void _showOwnerMenu() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _menuItem(Icons.edit_outlined,          'Таҳрир кардан',
              () { Navigator.pop(context); _editCaption(); }),
          _menuItem(Icons.visibility_off_outlined, 'Пинҳон кардани лайкҳо',
              () { Navigator.pop(context); _ctrl?.play(); }),
          _menuItem(Icons.comment_outlined,        'Хомӯш/Фаъол кардани шарҳ',
              () { Navigator.pop(context); _ctrl?.play(); }),
          _menuItem(Icons.share_outlined,          'Пинҳон кардани мубодила',
              () { Navigator.pop(context); _ctrl?.play(); }),
          _menuItem(Icons.alternate_email,         'Илова кардани зикр',
              () { Navigator.pop(context); _addMention(); }),
          _menuItem(Icons.bar_chart_rounded,       'Омор (Статистика)',
              () { Navigator.pop(context); _showStats(); }),
          _menuItem(Icons.delete_outline_rounded,  'Нест кардан',
              () { Navigator.pop(context); _deleteReel(); },
              color: Colors.redAccent),
          const SizedBox(height: 8),
        ],
      )),
    ).then((_) { if (!_paused) _ctrl?.play(); });
  }

  // ── ⋮ МЕНЮ — дигар корбар (Тоҷикӣ) ─────────────────────────
  void _showOtherMenu() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _menuItem(Icons.thumb_up_outlined,      'Ҷолиб аст',
              () { Navigator.pop(context); _markInterest(true); }),
          _menuItem(Icons.thumb_down_outlined,    'Ҷолиб нест',
              () { Navigator.pop(context); _markInterest(false); }),
          _menuItem(Icons.flag_outlined,          'Шикоят кардан',
              () { Navigator.pop(context); _report(); },
              color: Colors.redAccent),
          _menuItem(Icons.person_outline_rounded, 'Дидани профил',
              () { Navigator.pop(context); _openProfile(); }),
          _menuItem(Icons.block_rounded,          'Маҳдуд кардани тавсия',
              () { Navigator.pop(context); _ctrl?.play(); }),
          const SizedBox(height: 8),
        ],
      )),
    ).then((_) { if (!_paused) _ctrl?.play(); });
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    width: 36, height: 4,
    decoration: BoxDecoration(color: Colors.white24,
        borderRadius: BorderRadius.circular(2)));

  Widget _menuItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) => ListTile(
    leading: Icon(icon, color: color ?? Colors.white, size: 22),
    title: Text(label, style: TextStyle(
        color: color ?? Colors.white, fontSize: 15)),
    onTap: onTap,
  );

  // ── Actions ───────────────────────────────────────────────────
  Future<void> _editCaption() async {
    final ctrl = TextEditingController(text: widget.reel.caption);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Таҳрир кардан',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl, autofocus: true, maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Тавсиф...',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true, fillColor: Color(0xFF111111),
            border: OutlineInputBorder(borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Захира', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true) { if (!_paused) _ctrl?.play(); return; }
    await ApiClient.instance.put('/reels/${widget.reel.id}/caption',
        body: {'caption': ctrl.text.trim()});
    if (!_paused) _ctrl?.play();
  }

  Future<void> _addMention() async {
    final ctrl = TextEditingController();
    List results = [];
    bool searching = false;
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            _handle(),
            const Text('Зикр кардан',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: ctrl, autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Ном ё username...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.white38),
                  filled: true, fillColor: Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none)),
                onChanged: (q) async {
                  if (q.trim().isEmpty) { setS(() => results = []); return; }
                  setS(() => searching = true);
                  try {
                    final res = await ApiClient.instance
                        .get('/search', query: {'q': q});
                    if (res.statusCode < 400) {
                      final b = jsonDecode(res.body);
                      setS(() { results = b['users'] ?? []; searching = false; });
                    }
                  } catch (_) { setS(() => searching = false); }
                },
              )),
            const SizedBox(height: 8),
            Expanded(
              child: searching
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white30))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final u = results[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (u['avatar']?.isNotEmpty == true)
                                ? NetworkImage(u['avatar']) : null,
                            child: (u['avatar']?.isEmpty != false)
                                ? const Icon(Icons.person) : null),
                          title: Text('@${u['username']}',
                              style: const TextStyle(color: Colors.white)),
                          onTap: () { Navigator.pop(ctx); },
                        );
                      }),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (!_paused) _ctrl?.play();
  }

  Future<void> _showStats() async {
    final res = await ApiClient.instance
        .get('/reels/${widget.reel.id}/stats').catchError((_) => null);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Омор', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _statRow('👁 Тамошошуд', '${widget.reel.likesCount * 8}'),
          _statRow('❤ Лайк',       '${widget.reel.likesCount}'),
          _statRow('💬 Шарҳ',      '${widget.reel.commentsCount}'),
          _statRow('🔖 Захира',    '$_retweetCount'),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); if (!_paused) _ctrl?.play(); },
              child: const Text('Пӯшидан',
                  style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
  }

  Widget _statRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      Text(v, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.bold, fontSize: 15)),
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
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Нест кун', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) { if (!_paused) _ctrl?.play(); return; }
    await ApiClient.instance.delete('/reels/${widget.reel.id}');
    widget.onDelete();
  }

  Future<void> _markInterest(bool interested) async {
    await ApiClient.instance.post(
        '/posts/${widget.reel.id}/${interested ? 'interest' : 'not_interest'}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(interested ? 'Алгоритм навшуд ✓' : 'Рилс пинҳон шуд'),
      backgroundColor: interested ? Colors.green : Colors.grey[800],
      duration: const Duration(seconds: 2)));
    if (!_paused) _ctrl?.play();
  }

  Future<void> _report() async {
    final reasons = [
      ('spam',     'Спам'),
      ('violence', 'Зӯроварӣ'),
      ('adult',    'Мӯҳтавои калонсолон'),
      ('hate',     'Нафрат'),
      ('other',    'Дигар'),
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Шикоят кардан',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(r.$2, style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, r.$1),
          )).toList()),
      ),
    );
    if (reason == null) { if (!_paused) _ctrl?.play(); return; }
    await ApiClient.instance.post('/posts/${widget.reel.id}/report',
        body: {'reason': reason});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Шикоят фиристода шуд. Раҳмат!'),
        backgroundColor: Colors.green, duration: Duration(seconds: 2)));
    }
    if (!_paused) _ctrl?.play();
  }

  void _openComments() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _ReelComments(reelId: widget.reel.id)),
    ).then((_) { if (!_paused) _ctrl?.play(); });
  }

  void _share() {
    final url = 'https://raonson-v1.onrender.com/reels/${widget.reel.id}';
    _ctrl?.pause();
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
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
          }),
        const SizedBox(height: 8),
      ])),
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

        // ── Video ──────────────────────────────────────────────
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

        // ── Gradient ───────────────────────────────────────────
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x66000000), Colors.transparent,
                Color(0x33000000), Color(0xEE000000)],
            stops: [0, 0.35, 0.65, 1]),
        )),

        // ── Pause icon ─────────────────────────────────────────
        if (_paused)
          const Center(child: Icon(Icons.play_arrow_rounded,
              color: Colors.white54, size: 80,
              shadows: [Shadow(blurRadius: 20, color: Colors.black54)])),

        // ── Double-tap heart ───────────────────────────────────
        if (_showHeart) const Center(child: _HeartBurst()),

        // ── Progress bar — ПОЁН (мисли Instagram) ─────────────
        if (_initialized && _ctrl != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ValueListenableBuilder(
              valueListenable: _ctrl!,
              builder: (_, val, __) {
                final pos = val.position.inMilliseconds;
                final dur = val.duration.inMilliseconds;
                return LinearProgressIndicator(
                  value: dur > 0 ? pos / dur : 0,
                  // Қаблан кор шудааст → сафед бар зами тира
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 2,
                );
              }),
          ),

        // ── TOP BAR — МАРКАЗ "Рилсҳо | Дӯстон" + "+" ─────────
        Positioned(
          top: top + 12, left: 0, right: 0,
          child: Row(children: [
            const SizedBox(width: 16),
            const Spacer(),
            // ── "Рилсҳо | Дӯстон ∨" — МАРКАЗ ─────────────────
            GestureDetector(
              onTap: widget.onToggleFilter,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  widget.friendsFilter ? 'Дӯстон' : 'Рилсҳо',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
                ),
                const SizedBox(width: 6),
                const Text('|', style: TextStyle(
                    color: Colors.white54, fontSize: 16)),
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
            // "+" рост ─────────────────────────────────────────
            GestureDetector(
              onTap: widget.onAddReel,
              child: const Padding(padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.add, color: Colors.white, size: 28,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)]))),
          ]),
        ),

        // ── RIGHT ACTIONS ─────────────────────────────────────
        Positioned(
          right: 10, bottom: bottom + size.height * 0.10,
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            _ReelStableBtn(
              svgPath: 'assets/icons/heart.svg',
              activeSvgPath: 'assets/icons/heart_filled.svg',
              isActive: reel.isLiked, activeColor: Colors.red,
              count: _fmt(reel.likesCount), onTap: widget.onLike),
            const SizedBox(height: 22),

            _ReelStableBtn(
              svgPath: 'assets/icons/comment.svg',
              count: _fmt(reel.commentsCount), onTap: _openComments),
            const SizedBox(height: 22),

            _ReelStableBtn(
              svgPath: 'assets/icons/retweet.svg',
              count: _fmt(_retweetCount),
              onTap: () => setState(() => _retweetCount++)),
            const SizedBox(height: 22),

            _ReelStableBtn(
              svgPath: 'assets/icons/share.svg',
              count: '', onTap: _share),
            const SizedBox(height: 22),

            _ReelStableBtn(
              svgPath: 'assets/icons/save.svg',
              activeSvgPath: 'assets/icons/save_filled.svg',
              isActive: _saved, count: '',
              onTap: () { setState(() => _saved = !_saved); widget.onSave(); }),
            const SizedBox(height: 22),

            // ⋮ меню
            GestureDetector(
              onTap: _isOwner ? _showOwnerMenu : _showOtherMenu,
              child: const SizedBox(width: 30, height: 30,
                child: Icon(Icons.more_horiz_rounded,
                    color: Colors.white, size: 28,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)]))),
            const SizedBox(height: 16),

            // 🎵 Spinning disc
            _SpinningDisc(avatar: reel.user.avatar),
          ]),
        ),

        // ── BOTTOM LEFT — avatar + username + follow + caption + music
        Positioned(
          left: 14, right: 90,
          bottom: bottom + 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User row
              Row(children: [
                // ── Avatar бо story ring ──────────────────────
                GestureDetector(
                  onTap: _openProfile,
                  child: _AvatarWithStoryRing(
                    avatarUrl:    reel.user.avatar,
                    hasStory:     _hasStory,
                    storyViewed:  _storyViewed,
                  ),
                ),
                const SizedBox(width: 10),

                // Username — зер кун → профил
                Flexible(child: GestureDetector(
                  onTap: _openProfile,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(reel.user.username,
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (reel.user.verified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 14)],
                  ]),
                )),

                // "Пайравӣ кунед" — ТАНҲО агар дигар корбар бошад
                if (!_isOwner && !_following) ...[
                  const SizedBox(width: 10),
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
                        borderRadius: BorderRadius.circular(20)),
                      child: const Text('Пайравӣ кунед',
                        style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 12,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                    ),
                  ),
                ],
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

              // 🎵 Music
              Row(children: [
                const Icon(Icons.music_note_rounded, color: Colors.white, size: 15,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                const SizedBox(width: 5),
                Text(
                  reel.caption.isNotEmpty
                      ? reel.caption.split(' ').take(3).join(' ')
                      : 'оригинал садо',
                  style: const TextStyle(color: Colors.white70, fontSize: 13,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// AVATAR WITH STORY RING — мисли Instagram
// null=маълум нест, true=story дорад, false=story надорад
// ══════════════════════════════════════════════════════════════════
class _AvatarWithStoryRing extends StatelessWidget {
  final String avatarUrl;
  final bool?  hasStory;
  final bool   storyViewed;

  const _AvatarWithStoryRing({
    required this.avatarUrl,
    required this.hasStory,
    required this.storyViewed,
  });

  @override
  Widget build(BuildContext context) {
    // Story надорад → ҳалқа нест
    if (hasStory == false) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl, width: 42, height: 42, fit: BoxFit.cover,
          placeholder: (_, __) => Container(
              width: 42, height: 42, color: AppColors.card),
          errorWidget: (_, __, ___) => Container(
              width: 42, height: 42, color: AppColors.card,
              child: const Icon(Icons.person, color: Colors.white54, size: 22)),
        ),
      );
    }

    // Story дорад → ҳалқа бо rang
    // Надидагӣ → cyan→green | Дидагӣ → dark green
    final List<Color> gradientColors = storyViewed
        ? [const Color(0xFF2E5A3A), const Color(0xFF1E3D28)] // dark green
        : AppColors.storyGradient;                            // cyan → green

    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasStory == true
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        color: hasStory == null ? Colors.transparent : null,
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Colors.black),
        padding: const EdgeInsets.all(1.5),
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: double.infinity, height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.card),
                  errorWidget: (_, __, ___) => Container(
                      color: AppColors.card,
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 20)))
              : Container(color: AppColors.card,
                  child: const Icon(Icons.person,
                      color: Colors.white54, size: 20)),
        ),
      ),
    );
  }
}

// ── Stable Reel Button ──────────────────────────────────────────────
class _ReelStableBtn extends StatelessWidget {
  final String   svgPath;
  final String?  activeSvgPath;
  final bool     isActive;
  final Color    activeColor;
  final String   count;
  final VoidCallback onTap;

  const _ReelStableBtn({
    required this.svgPath,
    this.activeSvgPath,
    this.isActive    = false,
    this.activeColor = Colors.red,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final path  = (isActive && activeSvgPath != null) ? activeSvgPath! : svgPath;
    final color = isActive ? activeColor : Colors.white;
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 30, height: 30,
          child: SvgPicture.asset(path, width: 30, height: 30,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
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
  @override void initState() {
    super.initState();
    _spin = AnimationController(vsync: this,
        duration: const Duration(seconds: 5))..repeat();
  }
  @override void dispose() { _spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _spin,
    child: Container(
      width: 44, height: 44,
      decoration: const BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.storyGradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
        padding: const EdgeInsets.all(2),
        child: ClipOval(child: widget.avatar.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.avatar, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                    Icons.music_note_rounded, color: Colors.white54, size: 20))
            : const Icon(Icons.music_note_rounded, color: Colors.white54, size: 20)),
      ),
    ),
  );
}

// ── Heart burst ─────────────────────────────────────────────────────
class _HeartBurst extends StatefulWidget {
  const _HeartBurst();
  @override State<_HeartBurst> createState() => _HeartBurstState();
}
class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;
  @override void initState() {
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
  Widget build(BuildContext context) => AnimatedBuilder(animation: _ctrl,
    builder: (_, __) => Opacity(opacity: _opacity.value,
      child: Transform.scale(scale: _scale.value,
        child: const Icon(Icons.favorite, color: Colors.white, size: 120,
          shadows: [Shadow(blurRadius: 30, color: Colors.black54)]))));
}

// ── Reel Comments ───────────────────────────────────────────────────
class _ReelComments extends StatefulWidget {
  final String reelId;
  const _ReelComments({required this.reelId});
  @override State<_ReelComments> createState() => _ReelCommentsState();
}
class _ReelCommentsState extends State<_ReelComments> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true, _sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/reels/${widget.reelId}/comments');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['comments'] ?? []);
        setState(() { _comments = List<Map<String,dynamic>>.from(list); _loading = false; });
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
      await ApiClient.instance.post('/reels/${widget.reelId}/comments',
          body: {'text': text});
      _ctrl.clear(); _load();
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
      Text('Шарҳҳо (${_comments.length})', style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 4),
      const Divider(color: Colors.white10),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2,
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
                      return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          CircleAvatar(radius: 18, backgroundColor: AppColors.card,
                            backgroundImage: (u['avatar']??'').isNotEmpty
                                ? NetworkImage(u['avatar']) : null,
                            child: (u['avatar']??'').isEmpty
                                ? const Icon(Icons.person, color: Colors.white54, size: 18)
                                : null),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['username']??'', style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text(c['text']??'', style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                            ])),
                        ]));
                    }),
      ),
      SafeArea(child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 8,
            top: 8 + MediaQuery.of(context).viewInsets.bottom / 2),
        child: Row(children: [
          Expanded(child: TextField(controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'Шарҳ нависед...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
          const SizedBox(width: 10),
          GestureDetector(onTap: _send,
            child: _sending
                ? const SizedBox(width: 26, height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.neonBlue)))
                : const Icon(Icons.send_rounded, color: AppColors.neonBlue, size: 28)),
        ]),
      )),
    ]);
  }
}
