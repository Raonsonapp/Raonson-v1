// lib/search/search_screen.dart
// 100% Instagram-style: Explore → Recent → Results → Reels Feed
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../core/services/user_session.dart';
import '../core/services/follow_service.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../profile/profile_screen.dart';
import '../widgets/avatar.dart';
import '../widgets/verified_badge.dart';
import 'search_history.dart';

// ════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ════════════════════════════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer?  _debounce;
  String  _lastQ = '';

  // State machine
  // idle   → Explore grid (search bar NOT focused, no text)
  // recent → Recent history (search bar focused, no text)
  // result → Search results (has text)
  _Mode _mode = _Mode.idle;

  // Explore data
  List<_ExploreItem> _exploreItems  = [];
  bool               _exploreLoading = true;

  // Recent history
  List<String> _history = [];
  List<Map<String, dynamic>> _accounts = [];

  // Search results
  bool            _searching = false;
  List<UserModel> _users     = [];
  List<PostModel> _posts     = [];
  List<dynamic>   _reels     = [];
  List<dynamic>   _music     = [];
  List<dynamic>   _hashtags  = [];
  String?         _error;

  late final TabController _tabs;
  static const _tabLabels = ['Барои шумо', 'Аккаунтҳо', 'Аудио', 'Тегҳо'];

  // ── lifecycle ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadHistory();
    _loadExplore();

    _focus.addListener(() {
      if (!mounted) return;
      if (_focus.hasFocus && _ctrl.text.trim().isEmpty) {
        setState(() => _mode = _Mode.recent);
      } else if (!_focus.hasFocus && _ctrl.text.trim().isEmpty) {
        setState(() => _mode = _Mode.idle);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  // ── data loaders ─────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final h = await SearchHistory.load();
    final a = await SearchHistory.loadAccounts();
    if (mounted) setState(() { _history = h; _accounts = a; });
  }

  Future<void> _loadExplore() async {
    setState(() => _exploreLoading = true);
    try {
      final res = await ApiClient.instance.get('/explore');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;

        final items = <_ExploreItem>[];

        // Posts
        for (final p in (body['posts'] as List? ?? [])) {
          final post = PostModel.fromJson(p as Map<String, dynamic>);
          if (post.mediaUrl.isNotEmpty) {
            items.add(_ExploreItem(
              id:      post.id,
              url:     post.mediaUrl,
              type:    post.mediaType == 'video' ? _ItemType.video : _ItemType.image,
              isMulti: post.media.length > 1,
              views:   post.likesCount, // use likes as proxy; backend adds views later
              postData: post,
            ));
          }
        }

        // Reels
        for (final r in (body['reels'] as List? ?? [])) {
          final rm = r as Map<String, dynamic>;
          final url = rm['thumbnailUrl']?.toString()
              ?? rm['videoUrl']?.toString() ?? '';
          if (url.isNotEmpty) {
            items.add(_ExploreItem(
              id:    rm['_id']?.toString() ?? '',
              url:   url,
              type:  _ItemType.reel,
              views: (rm['viewsCount'] as num?)?.toInt()
                  ?? (rm['views'] as num?)?.toInt() ?? 0,
              reelData: rm,
            ));
          }
        }

        // Shuffle for variety
        items.shuffle();

        setState(() {
          _exploreItems   = items;
          _exploreLoading = false;
        });
      } else {
        if (mounted) setState(() => _exploreLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _exploreLoading = false);
    }
  }

  // ── search logic ─────────────────────────────────────────────────
  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _mode = _focus.hasFocus ? _Mode.recent : _Mode.idle;
        _users=[]; _posts=[]; _reels=[]; _music=[]; _hashtags=[]; _error=null;
      });
      _lastQ = '';
      return;
    }
    setState(() => _mode = _Mode.result);
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(q));
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
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(q)}'
          '&media=music&limit=15&country=US');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && mounted) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _music = (j['results'] as List? ?? [])
              .where((e) => (e['previewUrl'] ?? '').isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  // ── navigation ───────────────────────────────────────────────────
  void _cancelSearch() {
    _ctrl.clear();
    _focus.unfocus();
    _lastQ = '';
    setState(() {
      _mode = _Mode.idle;
      _users=[]; _posts=[]; _reels=[]; _music=[]; _hashtags=[]; _error=null;
    });
  }

  void _applyHistory(String q) {
    _ctrl.text = q;
    _focus.unfocus();
    _onChanged(q);
    Timer(const Duration(milliseconds: 50), () => _doSearch(q));
  }

  void _openProfile(String userId) {
    _focus.unfocus();
    // Аккаунти дидашударо ба «Охирин» сабт мекунем (мисли Instagram).
    final match = _users.where((e) => e.id == userId);
    if (match.isNotEmpty) {
      final u = match.first;
      SearchHistory.addAccount({
        'id':       u.id,
        'username': u.username,
        'avatar':   u.avatar,
        'verified': u.verified,
        'subtitle': u.fullName ?? '',
      });
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  // Long-press → пешнамоиши зуд (мисли Instagram)
  void _showExplorePreview(int index) {
    if (index < 0 || index >= _exploreItems.length) return;
    final item = _exploreItems[index];
    String authorId = '', authorName = '', authorAvatar = '';
    if (item.postData != null) {
      authorId     = item.postData!.user.id;
      authorName   = item.postData!.user.username;
      authorAvatar = item.postData!.user.avatar;
    } else if (item.reelData != null) {
      final u = item.reelData!['user'];
      if (u is Map) {
        authorId     = (u['_id'] ?? u['id'] ?? '').toString();
        authorName   = (u['username'] ?? '').toString();
        authorAvatar = (u['avatar'] ?? '').toString();
      }
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (ctx) => _ExplorePreviewDialog(
        item:         item,
        authorName:   authorName,
        authorAvatar: authorAvatar,
        onOpen: () { Navigator.pop(ctx); _openExploreAt(index); },
        onProfile: authorId.isEmpty ? null : () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: authorId)));
        },
        onShare: () {
          Navigator.pop(ctx);
          final kind = item.type == _ItemType.reel ? 'reels' : 'p';
          Share.share(
              'https://mahmadmurodov-raonson.hf.space/$kind/${item.id}');
        },
      ),
    );
  }

  // Open explore item → inline Reels-style feed
  void _openExploreAt(int index) {
    _focus.unfocus();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ExploreReelFeed(
        items:        _exploreItems,
        initialIndex: index,
      ),
    ));
  }

  // Open search result post → Reels-style feed from results
  void _openSearchResultAt(int index) {
    _focus.unfocus();
    final allItems = <_ExploreItem>[];
    for (final p in _posts) {
      if (p.mediaUrl.isNotEmpty) {
        allItems.add(_ExploreItem(
          id: p.id, url: p.mediaUrl,
          type: p.mediaType == 'video' ? _ItemType.video : _ItemType.image,
          isMulti: p.media.length > 1,
          views: p.likesCount,
          postData: p,
        ));
      }
    }
    for (final r in _reels) {
      final rm = r as Map<String, dynamic>;
      final url = rm['thumbnailUrl']?.toString()
          ?? rm['videoUrl']?.toString() ?? '';
      if (url.isNotEmpty) {
        allItems.add(_ExploreItem(
          id: rm['_id']?.toString() ?? '',
          url: url,
          type: _ItemType.reel,
          views: (rm['viewsCount'] as num?)?.toInt() ?? 0,
          reelData: rm,
        ));
      }
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ExploreReelFeed(items: allItems, initialIndex: index),
    ));
  }

  // ── build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _Mode.idle:   return _buildIdle();
      case _Mode.recent: return _buildRecent();
      case _Mode.result: return _buildResult();
    }
  }

  // ─── IDLE: search bar + explore grid ─────────────────────────────
  Widget _buildIdle() {
    return Column(
      key: const ValueKey('idle'),
      children: [
        // Search bar (not focused)
        _SearchBar(
          ctrl:       _ctrl,
          focus:      _focus,
          searching:  false,
          showCancel: false,
          onChanged:  _onChanged,
          onCancel:   _cancelSearch,
        ),
        Expanded(
          child: _exploreLoading
              ? _SkeletonGrid()
              : _ExploreGrid(
                  items:   _exploreItems,
                  onTap:   _openExploreAt,
                  onLongPress: _showExplorePreview,
                ),
        ),
      ],
    );
  }

  // ─── RECENT: full-screen history list ────────────────────────────
  Widget _buildRecent() {
    return Column(
      key: const ValueKey('recent'),
      children: [
        // Top: back arrow + search bar + cancel
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 14, 6),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: _cancelSearch,
            ),
            Expanded(
              child: _SearchBarRaw(
                ctrl:      _ctrl,
                focus:     _focus,
                searching: false,
                onChanged: _onChanged,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _cancelSearch,
              child: const Text('Бекор',
                  style: TextStyle(color: AppColors.neonBlue,
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        // History header
        if (_accounts.isNotEmpty || _history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(children: [
              Text('Охирин',
                  style: TextStyle(color: AppColors.textPrimary,
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
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Аккаунтҳои дидашуда
                ..._accounts.map(_recentAccountTile),
                // Ҷустуҷӯҳои матнӣ
                ..._history.map(_recentQueryTile),
              ],
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Text('Ҷустуҷӯи охирин нест',
                  style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.3), fontSize: 14)),
            ),
          ),
      ],
    );
  }

  Widget _recentAccountTile(Map<String, dynamic> a) {
    final id       = (a['id'] ?? '').toString();
    final username = (a['username'] ?? '').toString();
    final avatar   = (a['avatar'] ?? '').toString();
    final verified = a['verified'] == true;
    final subtitle = (a['subtitle'] ?? '').toString();
    return InkWell(
      onTap: () {
        _focus.unfocus();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Avatar(imageUrl: avatar, size: 44, glowBorder: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(username,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 13),
                  ],
                ]),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textFaint, fontSize: 12.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await SearchHistory.removeAccount(id);
              _loadHistory();
            },
            child: Icon(Icons.close_rounded,
                color: AppColors.textFaint, size: 18),
          ),
        ]),
      ),
    );
  }

  Widget _recentQueryTile(String q) {
    return InkWell(
      onTap: () => _applyHistory(q),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: AppColors.divider, shape: BoxShape.circle),
            child: Icon(Icons.history_rounded,
                color: AppColors.textTertiary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(q,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ),
          GestureDetector(
            onTap: () async {
              await SearchHistory.remove(q);
              _loadHistory();
            },
            child: Icon(Icons.close_rounded,
                color: AppColors.textFaint, size: 18),
          ),
        ]),
      ),
    );
  }

  // ─── RESULT: tabs + results ───────────────────────────────────────
  Widget _buildResult() {
    return Column(
      key: const ValueKey('result'),
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 14, 6),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: _cancelSearch,
            ),
            Expanded(
              child: _SearchBarRaw(
                ctrl:      _ctrl,
                focus:     _focus,
                searching: _searching,
                onChanged: _onChanged,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _cancelSearch,
              child: const Text('Бекор',
                  style: TextStyle(color: AppColors.neonBlue,
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        // Tabs
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.textPrimary,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.textPrimary,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelColor: AppColors.textFaint,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
        Divider(color: AppColors.divider, height: 1),
        // Tab views
        Expanded(
          child: _error != null
              ? _ErrView(msg: _error!)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    // Барои шумо — posts + reels grid
                    _ForYouTab(
                      posts:     _posts,
                      reels:     _reels,
                      users:     _users,
                      music:     _music,
                      loading:   _searching,
                      onUserTap: _openProfile,
                      onPostTap: _openSearchResultAt,
                    ),
                    // Аккаунтҳо
                    _UsersTab(
                        users: _users,
                        loading: _searching,
                        onTap: _openProfile),
                    // Аудио
                    _MusicTab(music: _music, loading: _searching),
                    // Тегҳо
                    _HashtagTab(
                        hashtags: _hashtags, loading: _searching),
                  ],
                ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SEARCH BAR WIDGETS
// ════════════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool searching;
  final bool showCancel;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;
  const _SearchBar({
    required this.ctrl, required this.focus,
    required this.searching, required this.showCancel,
    required this.onChanged, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(children: [
        Expanded(child: _SearchBarRaw(
            ctrl: ctrl, focus: focus,
            searching: searching, onChanged: onChanged)),
        if (showCancel) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onCancel,
            child: const Text('Бекор',
                style: TextStyle(color: AppColors.neonBlue,
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ]),
    );
  }
}

class _SearchBarRaw extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool searching;
  final ValueChanged<String> onChanged;
  const _SearchBarRaw({
    required this.ctrl, required this.focus,
    required this.searching, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        onChanged: onChanged,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Ҷустуҷӯ',
          hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 14),
          prefixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.neonBlue)))
              : Icon(Icons.search_rounded,
                  color: AppColors.textFaint, size: 20),
          suffixIcon: ctrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    ctrl.clear();
                    onChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textFaint, size: 18))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  EXPLORE GRID  (idle state) — strict 3-column uniform
// ════════════════════════════════════════════════════════════════════
enum _ItemType { image, video, reel }

class _ExploreItem {
  final String     id;
  final String     url;
  final _ItemType  type;
  final bool       isMulti;
  final int        views;
  final PostModel? postData;
  final Map<String, dynamic>? reelData;

  const _ExploreItem({
    required this.id,
    required this.url,
    required this.type,
    this.isMulti  = false,
    this.views    = 0,
    this.postData,
    this.reelData,
  });
}

class _ExploreGrid extends StatelessWidget {
  final List<_ExploreItem> items;
  final void Function(int index) onTap;
  final void Function(int index)? onLongPress;
  const _ExploreGrid({required this.items, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.explore_outlined,
              size: 52, color: AppColors.textPrimary.withOpacity(0.1)),
          const SizedBox(height: 12),
          Text('Мӯҳтаво ҳанӯз нест',
              style: TextStyle(
                  color: AppColors.textPrimary.withOpacity(0.3), fontSize: 14)),
        ]),
      );
    }

    // Гриди quilted — айнан мисли Instagram Explore (ҳуҷайраҳои баланди reel).
    return GridView.custom(
      padding: EdgeInsets.zero,
      gridDelegate: SliverQuiltedGridDelegate(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        repeatPattern: QuiltedGridRepeatPattern.inverted,
        pattern: const [
          QuiltedGridTile(2, 1), // ҳуҷайраи баланд (reel)
          QuiltedGridTile(1, 1),
          QuiltedGridTile(1, 1),
          QuiltedGridTile(1, 1),
        ],
      ),
      childrenDelegate: SliverChildBuilderDelegate(
        (_, i) => _ExploreCell(
          item:  items[i],
          onTap: () => onTap(i),
          onLongPress: onLongPress == null ? null : () => onLongPress!(i),
        ),
        childCount: items.length,
      ),
    );
  }
}

class _ExploreCell extends StatelessWidget {
  final _ExploreItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ExploreCell({required this.item, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(fit: StackFit.expand, children: [
        // Thumbnail
        CachedNetworkImage(
          imageUrl: item.url,
          fit: BoxFit.cover,
          placeholder: (_, __) =>
              Container(color: AppColors.surface),
          errorWidget: (_, __, ___) =>
              Container(color: AppColors.surface),
        ),
        // Reel icon (top-right)
        if (item.type == _ItemType.reel)
          Positioned(
            top: 6, right: 6,
            child: Icon(Icons.slow_motion_video_rounded,
                color: AppColors.textPrimary, size: 16,
                shadows: [Shadow(blurRadius: 6, color: AppColors.bg)]),
          ),
        // Multi icon
        if (item.isMulti && item.type != _ItemType.reel)
          Positioned(
            top: 6, right: 6,
            child: Icon(Icons.collections_rounded,
                color: AppColors.textPrimary, size: 16,
                shadows: [Shadow(blurRadius: 6, color: AppColors.bg)]),
          ),
        // Views counter (bottom-left) — shown if > 0
        if (item.views > 0)
          Positioned(
            bottom: 5, left: 5,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.remove_red_eye_rounded,
                  color: AppColors.textPrimary, size: 11,
                  shadows: [Shadow(blurRadius: 4, color: AppColors.bg)]),
              const SizedBox(width: 3),
              Text(_fmtViews(item.views),
                  style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 10,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: AppColors.bg)],
                  )),
            ]),
          ),
      ]),
    );
  }

  static String _fmtViews(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
    return '$v';
  }
}

// ════════════════════════════════════════════════════════════════════
//  EXPLORE LONG-PRESS PREVIEW (мисли Instagram)
// ════════════════════════════════════════════════════════════════════
class _ExplorePreviewDialog extends StatelessWidget {
  final _ExploreItem item;
  final String authorName, authorAvatar;
  final VoidCallback onOpen, onShare;
  final VoidCallback? onProfile;
  const _ExplorePreviewDialog({
    required this.item,
    required this.authorName,
    required this.authorAvatar,
    required this.onOpen,
    required this.onShare,
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Center(
        child: GestureDetector(
          onTap: () {}, // дохилро напӯшонад
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Author header
              if (authorName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Avatar(imageUrl: authorAvatar, size: 32, glowBorder: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(authorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textPrimary,
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              // Media preview
              AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.surface),
                ),
              ),
              // Action row (мисли Instagram menu)
              _act(Icons.open_in_full_rounded, 'Кушодан', onOpen),
              if (onProfile != null)
                _act(Icons.person_outline_rounded,
                    'Профили @$authorName', onProfile!),
              _act(Icons.share_outlined, 'Паҳн кардан', onShare),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _act(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.dividerFaint))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
          ),
          Icon(icon, color: AppColors.textSecondary, size: 20),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON GRID
// ════════════════════════════════════════════════════════════════════
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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1.0),
        itemCount: 18,
        itemBuilder: (_, __) => Container(
          color: Color.lerp(
              AppColors.surface, AppColors.card, _anim.value),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  EXPLORE REEL FEED  (full-screen vertical scroll after tapping)
//  Instagram: ← Reels, then shows posts/reels in feed starting at
//  the tapped index.
// ════════════════════════════════════════════════════════════════════
class _ExploreReelFeed extends StatefulWidget {
  final List<_ExploreItem> items;
  final int initialIndex;
  const _ExploreReelFeed(
      {required this.items, required this.initialIndex});

  @override
  State<_ExploreReelFeed> createState() => _ExploreReelFeedState();
}

class _ExploreReelFeedState extends State<_ExploreReelFeed> {
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() { _page.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        PageView.builder(
          controller:  _page,
          scrollDirection: Axis.vertical,
          itemCount:   widget.items.length,
          itemBuilder: (_, i) => _FeedCard(item: widget.items[i]),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 18),
                SizedBox(width: 4),
                Text('Reels',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 17,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// Single card in the explore feed (image OR playing video/reel)
class _FeedCard extends StatefulWidget {
  final _ExploreItem item;
  const _FeedCard({required this.item});
  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _liked = false, _saved = false, _muted = false;
  int  _likeCount = 0, _commentCount = 0;

  bool get _isVideo =>
      widget.item.type == _ItemType.video || widget.item.type == _ItemType.reel;
  bool get _isReel => widget.item.type == _ItemType.reel;
  String get _id => widget.item.id;

  @override
  void initState() {
    super.initState();
    final r = widget.item.reelData;
    final p = widget.item.postData;
    if (r != null) {
      _liked = r['isLiked'] == true;
      _saved = r['isSaved'] == true;
      _likeCount = (r['likesCount'] as num?)?.toInt() ?? 0;
      _commentCount = (r['commentsCount'] as num?)?.toInt() ?? 0;
    } else if (p != null) {
      _liked = p.liked; _saved = p.saved;
      _likeCount = p.likesCount; _commentCount = p.commentsCount;
    }
    if (_isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
      _video = c;
      await c.initialize();
      if (!mounted) return;
      c..setLooping(true)..play();
      setState(() => _ready = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    ApiClient.instance
        .post(_isReel ? '/reels/$_id/like' : '/posts/$_id/like')
        .then((_) {}, onError: (_) {});
  }

  void _toggleSave() {
    setState(() => _saved = !_saved);
    ApiClient.instance
        .post(_isReel ? '/reels/$_id/save' : '/posts/$_id/save')
        .then((_) {}, onError: (_) {});
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _video?.setVolume(_muted ? 0 : 1);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExploreCommentsSheet(
        id: _id, isReel: _isReel,
        onAdded: () { if (mounted) setState(() => _commentCount++); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Фони сиёҳ — мисли Instagram (на бежеви)
      ColoredBox(color: AppColors.bg),
      // ── Media: видеоро бозӣ мекунад, на ҳамчун расм (боги сиёҳ ислоҳ шуд) ──
      if (_isVideo)
        (_ready && _video != null
            ? GestureDetector(
                onTap: () => setState(() =>
                    _video!.value.isPlaying ? _video!.pause() : _video!.play()),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _video!.value.size.width,
                    height: _video!.value.size.height,
                    child: VideoPlayer(_video!),
                  ),
                ),
              )
            : Container(
                color: AppColors.bg,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.textFaint, strokeWidth: 2))))
      else
        // Расм пурра нишон дода мешавад (мисли Instagram) — буриш намешавад
        CachedNetworkImage(
          imageUrl: widget.item.url,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => ColoredBox(color: AppColors.bg),
          errorWidget: (_, __, ___) => ColoredBox(color: AppColors.bg),
        ),
      // Gradient overlay
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.55, 1.0],
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
      ),
      // Right side actions — иконкаҳои худамон (assets/icons), мисли reels
      Positioned(
        right: 12, bottom: 120,
        child: Column(children: [
          _ActionBtn(
              svg: _liked
                  ? 'assets/icons/heart_filled.svg'
                  : 'assets/icons/heart.svg',
              color: _liked ? Color(0xFFFF3040) : AppColors.textPrimary,
              label: _likeCount > 0 ? _fmt(_likeCount) : null,
              onTap: _toggleLike),
          const SizedBox(height: 18),
          _ActionBtn(
              svg: 'assets/icons/comment.svg',
              label: _commentCount > 0 ? _fmt(_commentCount) : null,
              onTap: _openComments),
          const SizedBox(height: 18),
          _ActionBtn(
              svg: 'assets/icons/share.svg',
              onTap: () => Share.share(widget.item.url)),
          const SizedBox(height: 18),
          _ActionBtn(
              svg: _saved
                  ? 'assets/icons/save_filled.svg'
                  : 'assets/icons/save.svg',
              onTap: _toggleSave),
          if (_isVideo) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _toggleMute,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: AppColors.textPrimary, size: 26),
            ),
          ],
        ]),
      ),
      // Bottom info
      if (widget.item.postData != null)
        Positioned(
          left: 14, right: 80, bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Avatar(imageUrl: widget.item.postData!.user.avatar, size: 32),
                const SizedBox(width: 8),
                Text(widget.item.postData!.user.username,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (widget.item.postData!.user.isVerified) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.verified_rounded,
                      color: AppColors.textPrimary, size: 14),
                ],
                const SizedBox(width: 10),
                _FollowChip(userId: widget.item.postData!.user.id),
              ]),
              if (widget.item.postData!.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.item.postData!.caption,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        )
      // Reel: user/ном/галочка/caption (мисли пост)
      else if (widget.item.reelData != null)
        Positioned(
          left: 14, right: 80, bottom: 40,
          child: Builder(builder: (_) {
            final u = (widget.item.reelData!['user'] ?? {}) as Map;
            final uname = (u['username'] ?? '').toString();
            final avatar = (u['avatar'] ?? '').toString();
            final verified = u['verified'] == true;
            final caption =
                (widget.item.reelData!['caption'] ?? '').toString();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Avatar(imageUrl: avatar, size: 32, name: uname),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(uname,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified_rounded,
                        color: AppColors.textPrimary, size: 14),
                  ],
                  const SizedBox(width: 10),
                  _FollowChip(userId: (u['_id'] ?? u['id'] ?? '').toString()),
                ]),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(caption,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            );
          }),
        ),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final String svg;
  final VoidCallback? onTap;
  final Color? color;
  final String? label;
  _ActionBtn(
      {required this.svg, this.onTap, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(
          svg,
          width: 30, height: 30,
          colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!,
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

class _FollowChip extends StatelessWidget {
  final String userId;
  const _FollowChip({this.userId = ''});

  bool get _isMe =>
      userId.isEmpty || userId == (UserSession.userId ?? '__none__');

  @override
  Widget build(BuildContext context) {
    // Дар пости ХУДАТ тугмаи «Пайравӣ» нишон дода намешавад.
    if (_isMe) return const SizedBox.shrink();
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: FollowService.instance.states,
      builder: (_, __, ___) {
        final following = FollowService.instance.resolve(userId, false);
        return GestureDetector(
          onTap: () => FollowService.instance.toggle(userId, following),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textSecondary),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(following ? 'Пайравӣ шуд' : 'Пайравӣ',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SEARCH RESULT TABS
// ════════════════════════════════════════════════════════════════════

// ── Барои шумо ───────────────────────────────────────────────────────
class _ForYouTab extends StatelessWidget {
  final List<UserModel> users;
  final List<PostModel> posts;
  final List<dynamic>   reels;
  final List<dynamic>   music;
  final bool            loading;
  final void Function(String) onUserTap;
  final void Function(int)    onPostTap;
  const _ForYouTab({
    required this.users, required this.posts,
    required this.reels, required this.music,
    required this.loading, required this.onUserTap,
    required this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Spin();
    if (users.isEmpty && posts.isEmpty && reels.isEmpty && music.isEmpty) {
      return const _NoResult();
    }

    // Build combined grid items (posts first, then reels)
    final gridItems = <_ExploreItem>[];
    for (final p in posts) {
      if (p.mediaUrl.isNotEmpty) {
        gridItems.add(_ExploreItem(
          id: p.id, url: p.mediaUrl,
          type: p.mediaType == 'video' ? _ItemType.video : _ItemType.image,
          isMulti: p.media.length > 1,
          views: p.likesCount,
          postData: p,
        ));
      }
    }
    for (final r in reels) {
      final rm = r as Map<String, dynamic>;
      final url = rm['thumbnailUrl']?.toString()
          ?? rm['videoUrl']?.toString() ?? '';
      if (url.isNotEmpty) {
        gridItems.add(_ExploreItem(
          id: rm['_id']?.toString() ?? '',
          url: url,
          type: _ItemType.reel,
          views: (rm['viewsCount'] as num?)?.toInt() ?? 0,
          reelData: rm,
        ));
      }
    }

    return CustomScrollView(
      slivers: [
        // Top accounts row (horizontal scroll)
        if (users.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Аккаунтҳо',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: users.length.clamp(0, 8),
                itemBuilder: (_, i) => _UserChip(
                    user: users[i],
                    onTap: () => onUserTap(users[i].id)),
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: Divider(color: AppColors.card, height: 16)),
        ],

        // Music strip
        if (music.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Аудио',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: music.take(3)
                  .map((m) => _MusicRow(m: m))
                  .toList(),
            ),
          ),
          SliverToBoxAdapter(
              child: Divider(color: AppColors.card, height: 16)),
        ],

        // Grid of posts/reels
        if (gridItems.isNotEmpty)
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ExploreCell(
                item:  gridItems[i],
                onTap: () => onPostTap(i),
              ),
              childCount: gridItems.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   3,
              mainAxisSpacing:  2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.0,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// Horizontal user chip
class _UserChip extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _UserChip({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Avatar(imageUrl: user.avatar, size: 48),
          const SizedBox(height: 4),
          Text(user.username,
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Аккаунтҳо ────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final bool loading;
  final void Function(String) onTap;
  const _UsersTab(
      {required this.users, required this.loading, required this.onTap});

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

// ── Аудио ─────────────────────────────────────────────────────────────
class _MusicTab extends StatelessWidget {
  final List<dynamic> music;
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

// ── Тегҳо ─────────────────────────────────────────────────────────────
class _HashtagTab extends StatelessWidget {
  final List<dynamic> hashtags;
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
        final h   = hashtags[i] as Map<String, dynamic>;
        final tag = h['tag']?.toString() ?? '';
        final cnt = (h['postsCount'] as num?)?.toInt() ?? 0;
        return InkWell(
          onTap: tag.isEmpty
              ? null
              : () => Navigator.pushNamed(context, '/hashtag', arguments: tag),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.tag_rounded,
                    color: AppColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#$tag',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('$cnt пост',
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12)),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  USER ROW
// ════════════════════════════════════════════════════════════════════
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
    setState(() => _loading = true);
    try {
      if (_following) {
        await ApiClient.instance.delete('/follow/${widget.user.id}');
      } else {
        await ApiClient.instance.post('/follow/${widget.user.id}');
      }
      if (mounted) setState(() { _following = !_following; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Avatar(imageUrl: widget.user.avatar, size: 48),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(widget.user.username,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (widget.user.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF00C853), size: 14),
                ],
              ]),
              if ((widget.user.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(widget.user.bio!,
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              Text('${_fmtFollowers(widget.user.followersCount)} обуначи',
                  style: TextStyle(
                      color: AppColors.textFaint, fontSize: 11)),
            ],
          )),
          if (!_isMe)
            GestureDetector(
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: _following
                      ? Colors.transparent : AppColors.neonBlue,
                  border: Border.all(
                      color: _following
                          ? AppColors.textFaint : AppColors.neonBlue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _loading
                    ? SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textPrimary))
                    : Text(
                        _following ? 'Пайрав' : 'Пайравӣ',
                        style: TextStyle(
                          color: _following
                              ? AppColors.textTertiary : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
              ),
            ),
        ]),
      ),
    );
  }

  static String _fmtFollowers(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}

// ════════════════════════════════════════════════════════════════════
//  MUSIC ROW
// ════════════════════════════════════════════════════════════════════
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _art.isNotEmpty
              ? Image.network(_art, width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _MusicPlaceholder())
              : _MusicPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500, fontSize: 13.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(_artist,
                style: TextStyle(
                    color: AppColors.textFaint, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        if (_ms > 0) ...[
          Text(_dur(_ms),
              style: TextStyle(
                  color: AppColors.textFaint, fontSize: 11)),
          const SizedBox(width: 10),
        ],
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _playing
                  ? AppColors.neonBlue
                  : AppColors.neonBlue.withOpacity(0.12),
              border: Border.all(
                  color: AppColors.neonBlue.withOpacity(0.5)),
            ),
            child: Icon(
                _playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: AppColors.textPrimary, size: 22),
          ),
        ),
      ]),
    );
  }
}

class _MusicPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 50, height: 50, color: AppColors.card,
      child: Icon(Icons.music_note_rounded,
          color: AppColors.textFaint, size: 22));
}

// ════════════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ════════════════════════════════════════════════════════════════════
enum _Mode { idle, recent, result }

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
      Icon(Icons.search_off_rounded,
          size: 52, color: AppColors.textPrimary.withOpacity(0.1)),
      const SizedBox(height: 10),
      Text('Ёфт нашуд',
          style: TextStyle(
              color: AppColors.textPrimary.withOpacity(0.3), fontSize: 14)),
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
        Icon(Icons.wifi_off_rounded,
            color: AppColors.textFaint, size: 48),
        const SizedBox(height: 12),
        Text('Пайвастшавӣ нашуд',
            style: TextStyle(
                color: AppColors.textTertiary, fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(msg,
            style: TextStyle(
                color: AppColors.textFaint, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Шарҳҳои explore (reel/post) — мисли reels ──────────────────────
class _ExploreCommentsSheet extends StatefulWidget {
  final String id;
  final bool isReel;
  final VoidCallback onAdded;
  const _ExploreCommentsSheet(
      {required this.id, required this.isReel, required this.onAdded});
  @override
  State<_ExploreCommentsSheet> createState() => _ExploreCommentsSheetState();
}

class _ExploreCommentsSheetState extends State<_ExploreCommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  String get _base => widget.isReel ? '/reels' : '/posts';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('$_base/${widget.id}/comments');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body is List ? body : (body['comments'] ?? [])) as List;
        setState(() {
          _comments = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _comments.insert(0, {
          'text': text,
          'user': {'username': UserSession.username ?? 'шумо'},
        }));
    widget.onAdded();
    try {
      await ApiClient.instance
          .post('$_base/${widget.id}/comments', body: {'text': text});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          Text('Шарҳҳо',
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 15)),
          Divider(color: AppColors.dividerFaint),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(
                    color: AppColors.textFaint, strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(child: Text('Ҳанӯз шарҳ нест',
                        style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final u = (c['user'] ?? {}) as Map;
                          return ListTile(
                            leading: Avatar(
                                imageUrl: (u['avatar'] ?? '').toString(),
                                name: (u['username'] ?? '').toString(),
                                size: 34),
                            title: Text((u['username'] ?? '').toString(),
                                style: TextStyle(color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text((c['text'] ?? '').toString(),
                                style: TextStyle(color: AppColors.textPrimary)),
                          );
                        }),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Шарҳ нависед...',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    filled: true, fillColor: AppColors.dividerFaint,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF1D9BF0)),
                onPressed: _send,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
