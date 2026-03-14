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

// ═══════════════════════════════════════════════════════════════════
//  SearchScreen
// ═══════════════════════════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {

  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _lastQ = '';

  bool   _loading = false;
  bool   _active  = false;

  List<UserModel>  _users = [];
  List<PostModel>  _posts = [];
  List             _reels = [];
  List             _music = [];
  String?          _error;

  late final TabController _tabs;
  static const _tabLabels = ['Ҳама','Корбарон','Постҳо','Рилҳо','Мусиқӣ'];

  // ── Idle категорияҳо ──────────────────────────────────────────
  static const _cats = [
    _Cat('Варзиш',    Icons.sports_soccer_rounded,  Color(0xFFFF6B35)),
    _Cat('Мусиқӣ',    Icons.music_note_rounded,     Color(0xFF9C27B0)),
    _Cat('Кино',      Icons.movie_rounded,           Color(0xFFE91E63)),
    _Cat('Хӯрок',     Icons.restaurant_rounded,      Color(0xFF4CAF50)),
    _Cat('Сафар',     Icons.flight_rounded,          Color(0xFF00BCD4)),
    _Cat('Мода',      Icons.style_rounded,           Color(0xFFFF9800)),
    _Cat('Технология',Icons.devices_rounded,         Color(0xFF3B9EFF)),
    _Cat('Бозӣ',      Icons.sports_esports_rounded, Color(0xFF673AB7)),
  ];

  static const _exploreImgs = [
    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
    'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=400',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
    'https://images.unsplash.com/photo-1581090464777-f3220bbe1b8b?w=400',
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400',
    'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?w=400',
    'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=400',
    'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?w=400',
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
    'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
    'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=400',
    'https://images.unsplash.com/photo-1550317138-10000687a72b?w=400',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  // ── Ҷустуҷӯ ──────────────────────────────────────────────────
  void _onChanged(String v) {
    _debounce?.cancel();
    setState(() => _active = v.isNotEmpty);

    if (v.trim().length < 2) {
      setState(() {
        _users = []; _posts = []; _reels = []; _music = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    if (q == _lastQ) return;
    _lastQ = q;

    setState(() { _loading = true; _error = null; });

    await Future.wait([
      _searchBackend(q),
      _searchMusic(q),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  // Backend → GET /search?q=...  →  { users: [...], posts: [...], reels: [...] }
  Future<void> _searchBackend(String q) async {
    try {
      final res = await ApiClient.instance.get(
        '/search',
        query: {'q': q},
      );
      if (!mounted) return;

      debugPrint('[Search] status=${res.statusCode}');

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List rawUsers = body['users'] ?? [];
        final List rawPosts = body['posts'] ?? [];
        final List rawReels = body['reels'] ?? [];

        setState(() {
          _users = rawUsers
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _posts = rawPosts
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _reels = rawReels;
        });
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Хатогӣ';
        if (mounted) setState(() => _error = msg);
      }
    } catch (e) {
      debugPrint('[Search] backend error: $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // iTunes API → мусиқӣ
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
      debugPrint('[Search] music error: $e');
    }
  }

  void _clear() {
    _ctrl.clear();
    _focus.unfocus();
    _lastQ = '';
    setState(() {
      _active = false;
      _users = []; _posts = []; _reels = []; _music = [];
      _error = null;
    });
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _active
                        ? AppColors.neonBlue.withOpacity(0.4)
                        : Colors.white.withOpacity(0.07)),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode:  _focus,
                  onChanged:  _onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Корбарон, постҳо, мусиқӣ...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 14),
                    prefixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.neonBlue)))
                        : const Icon(Icons.search_rounded,
                            color: Colors.white38, size: 20),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white38, size: 18),
                            onPressed: _clear)
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            if (_active) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _clear,
                child: const Text('Бекор',
                    style: TextStyle(color: AppColors.neonBlue,
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
        ),

        // ── ACTIVE: tabs + натиҷаҳо ──────────────────────────────
        if (_active) ...[
          TabBar(
            controller:           _tabs,
            isScrollable:         true,
            tabAlignment:         TabAlignment.start,
            indicatorColor:       AppColors.neonBlue,
            indicatorWeight:      2,
            indicatorSize:        TabBarIndicatorSize.label,
            labelColor:           Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle:           const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            dividerColor:         Colors.transparent,
            padding:              const EdgeInsets.symmetric(horizontal: 8),
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _error != null
                ? _ErrorView(msg: _error!)
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _AllTab(users: _users, posts: _posts,
                          reels: _reels, music: _music,
                          loading: _loading),
                      _UsersTab(users: _users, loading: _loading),
                      _PostsTab(posts: _posts, loading: _loading),
                      _ReelsTab(reels: _reels, loading: _loading),
                      _MusicTab(music: _music, loading: _loading),
                    ],
                  ),
          ),

        // ── IDLE: категорияҳо + explore grid ─────────────────────
        ] else ...[
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _cats.length,
              itemBuilder: (_, i) => _CatChip(
                cat: _cats[i],
                onTap: () {
                  _ctrl.text = _cats[i].label;
                  setState(() => _active = true);
                  _search(_cats[i].label);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFFF6B35), size: 16),
              const SizedBox(width: 6),
              Text('Trending',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: _exploreImgs.length,
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: _exploreImgs[i], fit: BoxFit.cover,
                placeholder:  (_, __) => Container(color: AppColors.card),
                errorWidget:  (_, __, ___) => Container(color: AppColors.card),
              ),
            ),
          ),
        ],
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  All Tab — ҳамаи натиҷаҳо
// ─────────────────────────────────────────────────────────────────
class _AllTab extends StatelessWidget {
  final List<UserModel> users;
  final List<PostModel> posts;
  final List reels, music;
  final bool loading;
  const _AllTab({required this.users, required this.posts,
      required this.reels, required this.music, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return _Spinner();
    if (users.isEmpty && posts.isEmpty && reels.isEmpty && music.isEmpty) {
      return _Empty();
    }
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      if (users.isNotEmpty) ...[
        _Header('Корбарон', Icons.person_rounded),
        ...users.take(3).map((u) => _UserRow(user: u)),
      ],
      if (music.isNotEmpty) ...[
        _Header('Мусиқӣ', Icons.music_note_rounded),
        ...music.take(4).map((m) => _MusicRow(m: m)),
      ],
      if (posts.isNotEmpty) ...[
        _Header('Постҳо', Icons.grid_on_rounded),
        _PostGrid(posts: posts.take(6).toList()),
      ],
      if (reels.isNotEmpty) ...[
        _Header('Рилҳо', Icons.play_circle_outline_rounded),
        _ReelGrid(reels: reels.take(6).toList()),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Users Tab
// ─────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final bool loading;
  const _UsersTab({required this.users, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return _Spinner();
    if (users.isEmpty) return _Empty();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: users.length,
      itemBuilder: (_, i) => _UserRow(user: users[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Posts Tab
// ─────────────────────────────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  final List<PostModel> posts;
  final bool loading;
  const _PostsTab({required this.posts, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return _Spinner();
    if (posts.isEmpty) return _Empty();
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) => _ImgThumb(url: posts[i].mediaUrl),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Reels Tab
// ─────────────────────────────────────────────────────────────────
class _ReelsTab extends StatelessWidget {
  final List reels;
  final bool loading;
  const _ReelsTab({required this.reels, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return _Spinner();
    if (reels.isEmpty) return _Empty();
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
          _ImgThumb(url: url),
          const Positioned(bottom: 8, left: 8,
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 22,
                shadows: [Shadow(blurRadius: 6)])),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Music Tab
// ─────────────────────────────────────────────────────────────────
class _MusicTab extends StatelessWidget {
  final List music;
  final bool loading;
  const _MusicTab({required this.music, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return _Spinner();
    if (music.isEmpty) return _Empty();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: music.length,
      itemBuilder: (_, i) => _MusicRow(m: music[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Post grid (All tab inline)
// ─────────────────────────────────────────────────────────────────
class _PostGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _PostGrid({required this.posts});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
    itemCount: posts.length,
    itemBuilder: (_, i) => _ImgThumb(url: posts[i].mediaUrl),
  );
}

class _ReelGrid extends StatelessWidget {
  final List reels;
  const _ReelGrid({required this.reels});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
    itemCount: reels.length,
    itemBuilder: (_, i) {
      final r   = reels[i] as Map;
      final url = r['thumbnailUrl']?.toString() ??
                  r['videoUrl']?.toString() ?? '';
      return Stack(fit: StackFit.expand, children: [
        _ImgThumb(url: url),
        const Positioned(bottom: 6, left: 6,
          child: Icon(Icons.play_arrow_rounded,
              color: Colors.white54, size: 18)),
      ]);
    },
  );
}

// ─────────────────────────────────────────────────────────────────
//  User Row
// ─────────────────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  final UserModel user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
    child: Row(children: [
      Avatar(imageUrl: user.avatar, size: 52),
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
        if (user.followersCount > 0)
          Text(_fmt(user.followersCount) + ' пайравон',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 11)),
      ])),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.neonBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
        ),
        child: const Text('Пайравӣ',
            style: TextStyle(color: AppColors.neonBlue,
                fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  String _fmt(int n) {
    if (n >= 1000000) return '${(n/1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────
//  Music Row
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
    final art    = m['artworkUrl100']?.toString()    ?? '';
    final title  = m['trackName']?.toString()        ?? '';
    final artist = m['artistName']?.toString()       ?? '';
    final ms     = (m['trackTimeMillis'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: art.isNotEmpty
              ? Image.network(art, width: 48, height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 48, height: 48, color: AppColors.card))
              : Container(width: 48, height: 48, color: AppColors.card,
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
//  Category chip (idle)
// ─────────────────────────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final _Cat cat;
  final VoidCallback onTap;
  const _CatChip({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 68, margin: const EdgeInsets.only(right: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cat.color.withOpacity(0.13),
            border: Border.all(color: cat.color.withOpacity(0.4)),
          ),
          child: Icon(cat.icon, color: cat.color, size: 24),
        ),
        const SizedBox(height: 5),
        Text(cat.label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 10.5),
            textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Header(this.label, this.icon);

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
//  Image thumbnail
// ─────────────────────────────────────────────────────────────────
class _ImgThumb extends StatelessWidget {
  final String url;
  const _ImgThumb({required this.url});

  @override
  Widget build(BuildContext context) => url.isNotEmpty
      ? CachedNetworkImage(
          imageUrl: url, fit: BoxFit.cover,
          placeholder:  (_, __) => Container(color: AppColors.card),
          errorWidget:  (_, __, ___) => Container(color: AppColors.card,
              child: const Icon(Icons.broken_image_outlined,
                  color: Colors.white12, size: 20)))
      : Container(color: AppColors.card);
}

// ─────────────────────────────────────────────────────────────────
//  Spinner / Empty / Error
// ─────────────────────────────────────────────────────────────────
class _Spinner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
        color: AppColors.neonBlue, strokeWidth: 2));
}

class _Empty extends StatelessWidget {
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

class _ErrorView extends StatelessWidget {
  final String msg;
  const _ErrorView({required this.msg});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
        const SizedBox(height: 12),
        Text('Пайвастшавӣ нашуд',
            style: const TextStyle(color: Colors.white54, fontSize: 15,
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
//  Models
// ─────────────────────────────────────────────────────────────────
class _Cat {
  final String   label;
  final IconData icon;
  final Color    color;
  const _Cat(this.label, this.icon, this.color);
}
