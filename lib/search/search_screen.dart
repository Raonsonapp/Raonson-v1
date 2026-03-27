import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../widgets/avatar.dart';
import '../profile/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {

  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer?  _debounce;
  String  _lastQ = '';

  // idle explore
  List<PostModel> _explorePosts = [];
  List            _exploreReels = [];
  bool            _exploreLoading = true;

  // search results
  bool            _searching = false;
  bool            _hasQuery  = false;
  List<UserModel> _users = [];
  List<PostModel> _posts = [];
  List            _reels = [];
  List            _music = [];
  String?         _error;

  late final TabController _tabs;
  static const _tabLabels = ['Ҳама', 'Корбарон', 'Постҳо', 'Рилҳо', 'Мусиқӣ'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _loadExplore();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  // ── Explore grid — реалии маълумот аз /explore ───────────────
  Future<void> _loadExplore() async {
    try {
      final res = await ApiClient.instance.get('/explore');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final rawPosts = body['posts'] as List? ?? [];
        final rawReels = body['reels'] as List? ?? [];
        setState(() {
          _explorePosts = rawPosts
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _exploreReels = rawReels;
          _exploreLoading = false;
        });
      } else {
        setState(() => _exploreLoading = false);
      }
    } catch (e) {
      debugPrint('[Search] explore error: $e');
      if (mounted) setState(() => _exploreLoading = false);
    }
  }

  // ── Ҷустуҷӯ ──────────────────────────────────────────────────
  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    setState(() => _hasQuery = q.isNotEmpty);

    if (q.length < 2) {
      setState(() {
        _users = []; _posts = []; _reels = [];
        _music = []; _error = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _doSearch(q),
    );
  }

  Future<void> _doSearch(String q) async {
    if (q == _lastQ) return;
    _lastQ = q;
    setState(() { _searching = true; _error = null; });

    await Future.wait([_searchBackend(q), _searchMusic(q)]);
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _searchBackend(String q) async {
    try {
      final res = await ApiClient.instance.get(
        '/search', query: {'q': q},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _users = (body['users'] as List? ?? [])
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _posts = (body['posts'] as List? ?? [])
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _reels = body['reels'] as List? ?? [];
        });
      } else {
        setState(() => _error = 'Хатогӣ: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[Search] backend: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _searchMusic(String q) async {
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(q)}&media=music&limit=15&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && mounted) {
        final j = jsonDecode(res.body);
        setState(() {
          _music = (j['results'] as List? ?? [])
              .where((e) => (e['previewUrl'] ?? '').isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[Search] music: $e');
    }
  }

  void _clearSearch() {
    _ctrl.clear();
    _focus.unfocus();
    _lastQ = '';
    setState(() {
      _hasQuery = false;
      _users = []; _posts = []; _reels = [];
      _music = []; _error = null;
    });
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  // ═══ BUILD ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [

        // ── SEARCH BAR ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode:  _focus,
                  onChanged:  _onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 14),
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.neonBlue)))
                        : const Icon(Icons.search_rounded,
                            color: Colors.white38, size: 20),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white38, size: 18),
                            onPressed: _clearSearch)
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            if (_hasQuery) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _clearSearch,
                child: const Text('Бекор',
                    style: TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
        ),

        // ── ҶУСТУҶӮ ФАЪОЛ → tabs ─────────────────────────────────
        if (_hasQuery) ...[
          TabBar(
            controller:           _tabs,
            isScrollable:         true,
            tabAlignment:         TabAlignment.start,
            indicatorColor:       AppColors.neonBlue,
            indicatorWeight:      2,
            indicatorSize:        TabBarIndicatorSize.label,
            labelColor:           Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            dividerColor:         Colors.transparent,
            padding:              const EdgeInsets.symmetric(horizontal: 8),
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _error != null
                ? _ErrView(msg: _error!)
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _AllTab(
                        users: _users, posts: _posts,
                        reels: _reels, music: _music,
                        loading: _searching,
                        onUserTap: _openProfile,
                      ),
                      _UsersTab(
                        users: _users, loading: _searching,
                        onTap: _openProfile),
                      _PostsTab(posts: _posts, loading: _searching),
                      _ReelsTab(reels: _reels, loading: _searching),
                      _MusicTab(music: _music, loading: _searching),
                    ],
                  ),
          ),

        // ── IDLE → explore grid ───────────────────────────────────
        ] else ...[
          Expanded(
            child: _exploreLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppColors.neonBlue, strokeWidth: 2))
                : _ExploreGrid(
                    posts: _explorePosts,
                    reels: _exploreReels,
                    onRefresh: _loadExplore,
                  ),
          ),
        ],
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Explore grid — ФАҚАТ маълумоти воқеӣ аз /explore
// ─────────────────────────────────────────────────────────────────
class _ExploreGrid extends StatelessWidget {
  final List<PostModel> posts;
  final List reels;
  final Future<void> Function() onRefresh;
  const _ExploreGrid({
    required this.posts, required this.reels, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Posts + reels якҷо омехта
    final items = <_GridItem>[];
    for (final p in posts) {
      if (p.mediaUrl.isNotEmpty) {
        items.add(_GridItem(url: p.mediaUrl, isReel: false));
      }
    }
    for (final r in reels) {
      final url = (r as Map)['cover']?.toString() ??
                  r['videoUrl']?.toString() ?? '';
      if (url.isNotEmpty) {
        items.add(_GridItem(url: url, isReel: true));
      }
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.neonBlue,
        child: ListView(children: [
          const SizedBox(height: 100),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.explore_outlined, size: 52,
                  color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text('Мӯҳтаво ҳанӯз нест',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 14)),
            ]),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.neonBlue,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: item.url,
              fit: BoxFit.cover,
              placeholder:  (_, __) => Container(color: AppColors.card),
              errorWidget:  (_, __, ___) => Container(color: AppColors.card),
            ),
            if (item.isReel)
              const Positioned(top: 6, right: 6,
                child: Icon(Icons.play_circle_filled_rounded,
                    color: Colors.white70, size: 18)),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  All tab
// ─────────────────────────────────────────────────────────────────
class _AllTab extends StatelessWidget {
  final List<UserModel> users;
  final List<PostModel> posts;
  final List reels, music;
  final bool loading;
  final void Function(String) onUserTap;
  const _AllTab({
    required this.users, required this.posts,
    required this.reels, required this.music,
    required this.loading, required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (users.isEmpty && posts.isEmpty && reels.isEmpty && music.isEmpty) {
      return const _NoResult();
    }
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      if (users.isNotEmpty) ...[
        _Hdr('Корбарон', Icons.person_rounded),
        ...users.take(4).map((u) => _UserRow(user: u, onTap: () => onUserTap(u.id))),
      ],
      if (music.isNotEmpty) ...[
        _Hdr('Мусиқӣ', Icons.music_note_rounded),
        ...music.take(3).map((m) => _MusicRow(m: m)),
      ],
      if (posts.isNotEmpty) ...[
        _Hdr('Постҳо', Icons.grid_on_rounded),
        _MiniGrid(items: posts.take(6).map((p) =>
            _GridItem(url: p.mediaUrl, isReel: false)).toList()),
      ],
      if (reels.isNotEmpty) ...[
        _Hdr('Рилҳо', Icons.play_circle_outline_rounded),
        _MiniGrid(items: reels.take(6).map((r) {
          final url = (r as Map)['thumbnailUrl']?.toString() ??
                      r['videoUrl']?.toString() ?? '';
          return _GridItem(url: url, isReel: true);
        }).toList()),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Users tab — танҳо avatar + ном, tap → профил
// ─────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final bool loading;
  final void Function(String) onTap;
  const _UsersTab({
    required this.users, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (users.isEmpty) return const _NoResult();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: users.length,
      itemBuilder: (_, i) =>
          _UserRow(user: users[i], onTap: () => onTap(users[i].id)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Posts tab
// ─────────────────────────────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  final List<PostModel> posts;
  final bool loading;
  const _PostsTab({required this.posts, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (posts.isEmpty) return const _NoResult();
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) => CachedNetworkImage(
        imageUrl: posts[i].mediaUrl, fit: BoxFit.cover,
        placeholder:  (_, __) => Container(color: AppColors.card),
        errorWidget:  (_, __, ___) => Container(color: AppColors.card),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Reels tab
// ─────────────────────────────────────────────────────────────────
class _ReelsTab extends StatelessWidget {
  final List reels;
  final bool loading;
  const _ReelsTab({required this.reels, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (reels.isEmpty) return const _NoResult();
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.6,
          mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: reels.length,
      itemBuilder: (_, i) {
        final r   = reels[i] as Map;
        final url = r['thumbnailUrl']?.toString() ??
                    r['videoUrl']?.toString() ?? '';
        return Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(
            imageUrl: url, fit: BoxFit.cover,
            placeholder:  (_, __) => Container(color: AppColors.card),
            errorWidget:  (_, __, ___) => Container(color: AppColors.card),
          ),
          const Positioned(bottom: 8, left: 8,
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 22,
                shadows: [Shadow(blurRadius: 8)])),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Music tab
// ─────────────────────────────────────────────────────────────────
class _MusicTab extends StatelessWidget {
  final List music;
  final bool loading;
  const _MusicTab({required this.music, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (music.isEmpty) return const _NoResult();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: music.length,
      itemBuilder: (_, i) => _MusicRow(m: music[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  User row — БЕ тугмаи "Пайравӣ", tap → профил
// ─────────────────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _UserRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Avatar(imageUrl: user.avatar, size: 46),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(user.username,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (user.verified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded,
                  color: AppColors.neonBlue, size: 14),
            ],
          ]),
          if ((user.bio ?? '').isNotEmpty)
            Text(user.bio!,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Icon(Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.2)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Music row
// ─────────────────────────────────────────────────────────────────
class _MusicRow extends StatelessWidget {
  final dynamic m;
  const _MusicRow({required this.m});

  String _dur(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final art    = m['artworkUrl100']?.toString() ?? '';
    final title  = m['trackName']?.toString()     ?? '';
    final artist = m['artistName']?.toString()    ?? '';
    final ms     = (m['trackTimeMillis'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: art.isNotEmpty
              ? Image.network(art, width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 48, height: 48, color: AppColors.card))
              : Container(width: 48, height: 48, color: const Color(0xFF1A1A1A),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.white24, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w500, fontSize: 13.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(artist,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 11.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (ms > 0) ...[
          Text(_dur(ms),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.28), fontSize: 11)),
          const SizedBox(width: 8),
        ],
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.neonBlue.withOpacity(0.1),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: AppColors.neonBlue, size: 18),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Mini grid (All tab)
// ─────────────────────────────────────────────────────────────────
class _MiniGrid extends StatelessWidget {
  final List<_GridItem> items;
  const _MiniGrid({required this.items});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
    itemCount: items.length,
    itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
      CachedNetworkImage(
        imageUrl: items[i].url, fit: BoxFit.cover,
        placeholder:  (_, __) => Container(color: AppColors.card),
        errorWidget:  (_, __, ___) => Container(color: AppColors.card),
      ),
      if (items[i].isReel)
        const Positioned(top: 4, right: 4,
          child: Icon(Icons.play_circle_filled_rounded,
              color: Colors.white70, size: 16)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────────
class _Hdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Hdr(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Row(children: [
      Icon(icon, color: AppColors.neonBlue, size: 15),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────
class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
        color: AppColors.neonBlue, strokeWidth: 2));
}

class _NoResult extends StatelessWidget {
  const _NoResult();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded, size: 52,
          color: Colors.white.withOpacity(0.1)),
      const SizedBox(height: 10),
      Text('Ёфт нашуд',
          style: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 14)),
    ]),
  );
}

class _ErrView extends StatelessWidget {
  final String msg;
  const _ErrView({required this.msg});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
        const SizedBox(height: 12),
        const Text('Пайвастшавӣ нашуд',
            style: TextStyle(color: Colors.white54, fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(msg,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Grid item model
// ─────────────────────────────────────────────────────────────────
class _GridItem {
  final String url;
  final bool   isReel;
  const _GridItem({required this.url, required this.isReel});
}
