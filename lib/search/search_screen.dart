// lib/search/search_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../widgets/avatar.dart';
import '../profile/profile_screen.dart';
import 'search_history.dart';

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

  // History
  List<String> _history = [];

  // Idle explore
  List<PostModel> _explorePosts  = [];
  List            _exploreReels  = [];
  bool            _exploreLoading = true;

  // Search results
  bool            _searching = false;
  bool            _hasQuery  = false;
  List<UserModel> _users = [];
  List<PostModel> _posts = [];
  List            _reels = [];
  List            _music = [];
  List            _hashtags = [];
  String?         _error;

  late final TabController _tabs;
  // Instagram-style 4 tabs when searching
  static const _tabLabels = ['Барои шумо', 'Аккаунтҳо', 'Аудио', 'Тегҳо'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadHistory();
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

  Future<void> _loadHistory() async {
    final h = await SearchHistory.load();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _loadExplore() async {
    setState(() => _exploreLoading = true);
    try {
      final res = await ApiClient.instance.get('/explore');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _explorePosts = (body['posts'] as List? ?? [])
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _exploreReels = body['reels'] as List? ?? [];
          _exploreLoading = false;
        });
      } else {
        if (mounted) setState(() => _exploreLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _exploreLoading = false);
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    setState(() => _hasQuery = q.isNotEmpty);
    if (q.length < 2) {
      setState(() { _users=[]; _posts=[]; _reels=[]; _music=[]; _hashtags=[]; _error=null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    if (q == _lastQ) return;
    _lastQ = q;
    setState(() { _searching = true; _error = null; });
    await SearchHistory.add(q);
    await _loadHistory();
    await Future.wait([_searchBackend(q), _searchMusic(q)]);
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _searchBackend(String q) async {
    try {
      final res = await ApiClient.instance.get('/search', query: {'q': q});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _users = (body['users'] as List? ?? [])
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
          _posts = (body['posts'] as List? ?? [])
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
          _reels    = body['reels']    as List? ?? [];
          _hashtags = body['hashtags'] as List? ?? [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _searchMusic(String q) async {
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(q)}&media=music&limit=15&country=US');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && mounted) {
        final j = jsonDecode(res.body);
        setState(() {
          _music = (j['results'] as List? ?? [])
              .where((e) => (e['previewUrl'] ?? '').isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  void _clearSearch() {
    _ctrl.clear();
    _focus.unfocus();
    _lastQ = '';
    setState(() {
      _hasQuery = false;
      _users=[]; _posts=[]; _reels=[]; _music=[]; _hashtags=[]; _error=null;
    });
  }

  void _openProfile(String userId) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  void _applyHistory(String q) {
    _ctrl.text = q;
    _onChanged(q);
    _doSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(child: Column(children: [
        // ── Search bar ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.transparent),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                    prefixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue)))
                        : const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
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
                    style: TextStyle(color: AppColors.neonBlue,
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ] else if (_focus.hasFocus) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () { _focus.unfocus(); _clearSearch(); },
                child: const Text('Бекор',
                    style: TextStyle(color: AppColors.neonBlue,
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
        ),

        if (_hasQuery) ...[
          // ── Tabs ────────────────────────────────────────────────
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _error != null
                ? _ErrView(msg: _error!)
                : TabBarView(
                    controller: _tabs,
                    children: [
                      // 1. Барои шумо - posts + reels grid (like Instagram)
                      _AllTab(users: _users, posts: _posts, reels: _reels,
                          music: _music, loading: _searching, onUserTap: _openProfile),
                      // 2. Аккаунтҳо
                      _UsersTab(users: _users, loading: _searching, onTap: _openProfile),
                      // 3. Аудио
                      _MusicTab(music: _music, loading: _searching),
                      // 4. Тегҳо
                      _HashtagTab(hashtags: _hashtags, loading: _searching),
                    ],
                  ),
          ),
        ] else ...[
          // ── IDLE ────────────────────────────────────────────────
          Expanded(
            child: CustomScrollView(slivers: [
              // Recent searches
              if (_history.isNotEmpty) ...[
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(children: [
                    const Text('Охирин',
                        style: TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await SearchHistory.clear();
                        _loadHistory();
                      },
                      child: const Text('Ҳамаро тоза кун',
                          style: TextStyle(color: AppColors.neonBlue,
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                )),
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final q = _history[i];
                    return ListTile(
                      leading: Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(
                              color: Color(0xFF1C1C1C), shape: BoxShape.circle),
                          child: const Icon(Icons.history,
                              color: Colors.white38, size: 20)),
                      title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white24, size: 18),
                        onPressed: () async {
                          await SearchHistory.remove(q);
                          _loadHistory();
                        },
                      ),
                      onTap: () => _applyHistory(q),
                      dense: true,
                    );
                  },
                  childCount: _history.length,
                )),
                const SliverToBoxAdapter(child: Divider(color: Colors.white10, height: 24)),
              ],

              // Explore grid header
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: const SizedBox.shrink(), // No header like Instagram
              )),

              // Instagram-style grid
              _exploreLoading
                  ? SliverToBoxAdapter(child: _SkeletonGrid())
                  : _InstagramGrid(posts: _explorePosts, reels: _exploreReels),
            ]),
          ),
        ],
      ])),
    );
  }
}

// ── Instagram-style grid (big cell every 7th) ────────────────────────
class _InstagramGrid extends StatelessWidget {
  final List<PostModel> posts;
  final List reels;
  const _InstagramGrid({required this.posts, required this.reels});

  @override
  Widget build(BuildContext context) {
    final items = <_GridItem>[];
    for (final p in posts) {
      if (p.mediaUrl.isNotEmpty) {
        items.add(_GridItem(url: p.mediaUrl, isReel: false,
            isMulti: p.media.length > 1));
      }
    }
    for (final r in reels) {
      final url = (r as Map)['thumbnailUrl']?.toString()
          ?? r['videoUrl']?.toString() ?? '';
      if (url.isNotEmpty) {
        items.add(_GridItem(url: url, isReel: true));
      }
    }

    if (items.isEmpty) {
      return SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.explore_outlined, size: 52,
              color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          Text('Мӯҳтаво ҳанӯз нест',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14)),
        ])),
      ));
    }

    // Build rows manually: Instagram pattern
    // Every 7 items: 1 big (2 cols) + 2 small on right
    // Other rows: 3 equal columns
    return SliverToBoxAdapter(
      child: _InstagramGridWidget(items: items),
    );
  }
}

class _InstagramGridWidget extends StatelessWidget {
  final List<_GridItem> items;
  const _InstagramGridWidget({required this.items});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cell = (w - 4) / 3; // 3 columns, 2px gap
    final bigCell = cell * 2 + 2;

    final widgets = <Widget>[];
    int i = 0;
    int blockCount = 0;

    while (i < items.length) {
      // Every 3rd block (0-indexed): big layout
      if (blockCount % 3 == 0 && i + 2 < items.length) {
        // Big cell left + 2 small right
        final big   = items[i];
        final sm1   = items[i + 1];
        final sm2   = items[i + 2];
        widgets.add(SizedBox(
          height: bigCell,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _GridTile(item: big, width: bigCell, height: bigCell),
            const SizedBox(width: 2),
            Column(children: [
              _GridTile(item: sm1, width: cell, height: cell),
              const SizedBox(height: 2),
              _GridTile(item: sm2, width: cell, height: cell),
            ]),
          ]),
        ));
        widgets.add(const SizedBox(height: 2));
        i += 3;
        blockCount++;
      } else if (blockCount % 3 == 1 && i + 2 < items.length) {
        // 2 small left + big cell right
        final sm1 = items[i];
        final sm2 = items[i + 1];
        final big = items[i + 2];
        widgets.add(SizedBox(
          height: bigCell,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              _GridTile(item: sm1, width: cell, height: cell),
              const SizedBox(height: 2),
              _GridTile(item: sm2, width: cell, height: cell),
            ]),
            const SizedBox(width: 2),
            _GridTile(item: big, width: bigCell, height: bigCell),
          ]),
        ));
        widgets.add(const SizedBox(height: 2));
        i += 3;
        blockCount++;
      } else {
        // Regular 3-column row
        final rowItems = items.skip(i).take(3).toList();
        widgets.add(Row(
          children: List.generate(rowItems.length, (j) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GridTile(item: rowItems[j], width: cell, height: cell),
              if (j < rowItems.length - 1) const SizedBox(width: 2),
            ],
          )),
        ));
        widgets.add(const SizedBox(height: 2));
        i += rowItems.length;
        blockCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

// ── Skeleton loader ──────────────────────────────────────────────────
class _SkeletonGrid extends StatefulWidget {
  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          color: Color.lerp(const Color(0xFF111111), const Color(0xFF222222), _anim.value),
        ),
      ),
    );
  }
}

// ── Grid tile ────────────────────────────────────────────────────────
class _GridTile extends StatelessWidget {
  final _GridItem item;
  final double width;
  final double height;
  const _GridTile({required this.item, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (item.postId.isNotEmpty) {
          Navigator.pushNamed(context, '/post-detail',
              arguments: item.postId);
        }
      },
      child: SizedBox(
        width: width, height: height,
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(
            imageUrl: item.url, fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF111111)),
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF111111)),
          ),
          if (item.isReel)
            const Positioned(top: 6, right: 6,
              child: Icon(Icons.play_circle_filled_rounded,
                  color: Colors.white70, size: 18)),
          if (item.isMulti)
            const Positioned(top: 6, right: 6,
              child: Icon(Icons.collections_rounded,
                  color: Colors.white, size: 18)),
        ]),
      ),
    );
  }
}

// ── All tab ──────────────────────────────────────────────────────────
class _AllTab extends StatelessWidget {
  final List<UserModel> users;
  final List<PostModel> posts;
  final List reels, music;
  final bool loading;
  final void Function(String) onUserTap;
  const _AllTab({required this.users, required this.posts,
      required this.reels, required this.music,
      required this.loading, required this.onUserTap});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (users.isEmpty && posts.isEmpty && reels.isEmpty && music.isEmpty) return const _NoResult();
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
        _MiniGrid(items: posts.take(6).map((p) => _GridItem(url: p.mediaUrl, isReel: false)).toList()),
      ],
    ]);
  }
}

// ── Users tab ────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final bool loading;
  final void Function(String) onTap;
  const _UsersTab({required this.users, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (users.isEmpty) return const _NoResult();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: users.length,
      itemBuilder: (_, i) => _UserRow(user: users[i], onTap: () => onTap(users[i].id)),
    );
  }
}

// ── Posts tab ────────────────────────────────────────────────────────
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
      itemBuilder: (_, i) => GestureDetector(
        onTap: () {},
        child: CachedNetworkImage(
          imageUrl: posts[i].mediaUrl, fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFF111111)),
          errorWidget: (_, __, ___) => Container(color: const Color(0xFF111111)),
        ),
      ),
    );
  }
}

// ── Reels tab ────────────────────────────────────────────────────────
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
        final r = reels[i] as Map;
        final url = r['thumbnailUrl']?.toString() ?? r['videoUrl']?.toString() ?? '';
        return Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF111111)),
            errorWidget: (_, __, ___) => Container(color: const Color(0xFF111111))),
          const Positioned(bottom: 8, left: 8,
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22,
                shadows: [Shadow(blurRadius: 8)])),
        ]);
      },
    );
  }
}

// ── Music tab ────────────────────────────────────────────────────────
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

// ── Hashtag tab ──────────────────────────────────────────────────────
class _HashtagTab extends StatelessWidget {
  final List hashtags;
  final bool loading;
  const _HashtagTab({required this.hashtags, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (hashtags.isEmpty) return const _NoResult();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: hashtags.length,
      itemBuilder: (_, i) {
        final h = hashtags[i] as Map<String, dynamic>;
        final tag   = h['tag']?.toString() ?? '';
        final count = h['postsCount'] ?? 0;
        return ListTile(
          leading: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tag_rounded, color: Colors.white70, size: 22),
          ),
          title: Text('#$tag',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text('$count пост',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () {},
        );
      },
    );
  }
}

// ── User row with FOLLOW button ──────────────────────────────────────
class _UserRow extends StatefulWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _UserRow({required this.user, required this.onTap});
  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _following = false;
  bool _loading   = false;

  bool get _isMe => UserSession.userId == widget.user.id;

  Future<void> _toggle() async {
    if (_loading || _isMe) return;
    setState(() { _loading = true; });
    try {
      if (_following) {
        await ApiClient.instance.delete('/follow/${widget.user.id}');
      } else {
        await ApiClient.instance.post('/follow/${widget.user.id}');
      }
      if (mounted) setState(() { _following = !_following; _loading = false; });
      // Invalidate profile cache after follow change
      // (counter updates on next profile load)
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: widget.onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Avatar(imageUrl: widget.user.avatar, size: 46),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.user.username,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (widget.user.verified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, color: AppColors.neonBlue, size: 14),
            ],
          ]),
          if ((widget.user.bio ?? '').isNotEmpty)
            Text(widget.user.bio!,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (!_isMe)
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _following ? Colors.transparent : AppColors.neonBlue,
                border: Border.all(
                  color: _following ? Colors.white30 : AppColors.neonBlue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _loading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_following ? 'Пайрав' : 'Пайравӣ',
                      style: TextStyle(
                        color: _following ? Colors.white54 : Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    ),
  );
}

// ── Music row with AUDIO PREVIEW ─────────────────────────────────────
final _audioPlayer = AudioPlayer();
String? _playingUrl;

class _MusicRow extends StatefulWidget {
  final dynamic m;
  const _MusicRow({required this.m});
  @override
  State<_MusicRow> createState() => _MusicRowState();
}

class _MusicRowState extends State<_MusicRow> {
  bool _playing = false;

  String get _previewUrl => widget.m['previewUrl']?.toString() ?? '';
  String get _title      => widget.m['trackName']?.toString()  ?? '';
  String get _artist     => widget.m['artistName']?.toString() ?? '';
  String get _art        => widget.m['artworkUrl100']?.toString() ?? '';
  int    get _ms         => (widget.m['trackTimeMillis'] as num?)?.toInt() ?? 0;

  String _dur(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _audioPlayer.pause();
      setState(() { _playing = false; _playingUrl = null; });
    } else {
      if (_playingUrl != null && _playingUrl != _previewUrl) {
        await _audioPlayer.stop();
      }
      _playingUrl = _previewUrl;
      await _audioPlayer.play(UrlSource(_previewUrl));
      if (mounted) setState(() => _playing = true);
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() { _playing = false; _playingUrl = null; });
      });
    }
  }

  @override
  void dispose() {
    if (_playingUrl == _previewUrl) {
      _audioPlayer.pause();
      _playingUrl = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _art.isNotEmpty
            ? Image.network(_art, width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: const Color(0xFF1A1A1A)))
            : Container(width: 48, height: 48, color: const Color(0xFF1A1A1A),
                child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 22)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_title,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w500, fontSize: 13.5),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(_artist,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11.5),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      if (_ms > 0) ...[
        Text(_dur(_ms), style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 11)),
        const SizedBox(width: 8),
      ],
      GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _playing ? AppColors.neonBlue : AppColors.neonBlue.withOpacity(0.1),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
          ),
          child: Icon(
            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

// ── Mini grid ────────────────────────────────────────────────────────
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
      CachedNetworkImage(imageUrl: items[i].url, fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFF111111)),
        errorWidget: (_, __, ___) => Container(color: const Color(0xFF111111))),
      if (items[i].isReel)
        const Positioned(top: 4, right: 4,
          child: Icon(Icons.play_circle_filled_rounded, color: Colors.white70, size: 16)),
    ]),
  );
}

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

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2));
}

class _NoResult extends StatelessWidget {
  const _NoResult();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.search_off_rounded, size: 52, color: Colors.white.withOpacity(0.1)),
    const SizedBox(height: 10),
    Text('Ёфт нашуд', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
  ]));
}

class _ErrView extends StatelessWidget {
  final String msg;
  const _ErrView({required this.msg});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
      const SizedBox(height: 12),
      const Text('Пайвастшавӣ нашуд',
          style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(msg, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          textAlign: TextAlign.center),
    ]),
  ));
}

class _GridItem {
  final String url;
  final bool isReel;
  final bool isMulti;
  const _GridItem({required this.url, required this.isReel, this.isMulti = false});
}
