// lib/feed/hashtag/hashtag_screen.dart
//
// Саҳифаи хештег — мисли Instagram: сарлавҳа (#тег, шумораи постҳо,
// «Обуна шудан», хештегҳои алоқаманд) ва ду таб «Беҳтарин» / «Нав» —
// гриди омехтаи постҳо ва Reels, саҳифа-саҳифа.
//
// Пеш танҳо постҳо (бе Reels) рӯйхат мешуданд, шумора ва обуна набуд,
// ва хештеги тоҷикӣ аз тавсиф бо матни холӣ меомад.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_theme.dart';
import '../../core/hashtags/hashtag_parser.dart';
import '../../core/hashtags/hashtag_repository.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/video_frame.dart';
import '../../reels/single_reel_screen.dart';
import '../post/post_detail_screen.dart';

class HashtagScreen extends StatefulWidget {
  final String hashtag; // бо ё бе «#»
  const HashtagScreen({super.key, required this.hashtag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  late final String _tag =
      normalizeHashtag(widget.hashtag) ?? widget.hashtag.replaceFirst('#', '').toLowerCase();
  HashtagInfo? _info;
  bool _loading = true;
  bool _busyFollow = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final info = await HashtagRepository.instance.info(_tag);
      if (!mounted) return;
      setState(() { _info = info; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _error = tr('common.noConnection'); });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final info = _info;
    if (info == null || _busyFollow) return;
    final want = !info.following;
    // Фавран нишон медиҳем; хато → бармегардонем.
    setState(() { _busyFollow = true; _info = info.copyWith(following: want); });
    try {
      final now = await HashtagRepository.instance.setFollowing(_tag, want);
      if (mounted) setState(() => _info = _info!.copyWith(following: now));
    } catch (_) {
      if (mounted) {
        setState(() => _info = _info!.copyWith(following: !want));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('common.noConnection'))));
      }
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Widget _header(HashtagInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            alignment: Alignment.center,
            child: Text('#', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 34,
                fontWeight: FontWeight.w300)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                info.hidden
                    ? '—'
                    : tr('hashtag.postsCount', {'n': compactCount(info.postsCount)}),
                key: const ValueKey('hashtag-count'),
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (!info.hidden)
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: info.following
                      ? OutlinedButton(
                          key: const ValueKey('hashtag-follow'),
                          onPressed: _busyFollow ? null : _toggleFollow,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(tr('hashtag.following'),
                              style: TextStyle(color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        )
                      : ElevatedButton(
                          key: const ValueKey('hashtag-follow'),
                          onPressed: _busyFollow ? null : _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(tr('hashtag.follow'),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                ),
            ]),
          ),
        ]),
        if (info.related.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('hashtag.related'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: info.related.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = info.related[i];
                return ActionChip(
                  key: ValueKey('related-${r.tag}'),
                  label: Text('#${r.tag}'),
                  labelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  backgroundColor: AppColors.card,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/hashtag', arguments: r.tag),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    } else if (_error != null || info == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.error_outline, color: AppColors.textFaint, size: 48),
          const SizedBox(height: 12),
          Text(_error ?? '', style: TextStyle(color: AppColors.textFaint)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue),
            child: Text(tr('hashtag.retry')),
          ),
        ]),
      );
    } else if (info.hidden) {
      // Хештеги манъшуда — мисли Instagram: сарлавҳа ва огоҳӣ, бе грид.
      body = ListView(children: [
        _header(info),
        const SizedBox(height: 40),
        Icon(AppIcons.visibility_off_rounded, color: AppColors.textFaint, size: 48),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            info.notice.isNotEmpty ? info.notice : tr('hashtag.hidden'),
            key: const ValueKey('hashtag-hidden'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ]);
    } else {
      body = DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(child: _header(info)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(TabBar(
                indicatorColor: AppColors.textPrimary,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textFaint,
                dividerColor: AppColors.divider,
                tabs: [
                  Tab(text: tr('hashtag.top')),
                  Tab(text: tr('hashtag.recent')),
                ],
              )),
            ),
          ],
          body: TabBarView(children: [
            _HashtagGrid(key: const PageStorageKey('top'), tag: _tag, top: true),
            _HashtagGrid(key: const PageStorageKey('recent'), tag: _tag, top: false),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('#$_tag',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: body,
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  final TabBar bar;
  _TabsHeader(this.bar);
  @override
  double get minExtent => bar.preferredSize.height;
  @override
  double get maxExtent => bar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: AppColors.bg, child: bar);
  @override
  bool shouldRebuild(_TabsHeader old) => old.bar != bar;
}

/// Гриди «Беҳтарин» ё «Нав» — саҳифа-саҳифа (24-тоӣ).
class _HashtagGrid extends StatefulWidget {
  final String tag;
  final bool top;
  const _HashtagGrid({super.key, required this.tag, required this.top});

  @override
  State<_HashtagGrid> createState() => _HashtagGridState();
}

class _HashtagGridState extends State<_HashtagGrid>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 24;
  List<HashtagItem> _items = [];
  bool _loading = true, _hasMore = false, _loadingMore = false;
  String? _error;
  int _page = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<HashtagPage> _fetch(int page) => HashtagRepository.instance
      .page(widget.tag, top: widget.top, page: page, limit: _pageSize);

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final p = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _items = p.items;
        _hasMore = p.hasMore;
        _page = 1;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = tr('common.noConnection'); });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    _loadingMore = true;
    try {
      final p = await _fetch(_page + 1);
      if (!mounted) return;
      final seen = _items.map((e) => e.id).toSet();
      final fresh = p.items.where((e) => seen.add(e.id)).toList();
      setState(() {
        _page++;
        _items = [..._items, ...fresh];
        _hasMore = p.hasMore && fresh.isNotEmpty;
      });
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  void _open(int index) {
    final item = _items[index];
    if (item.isReel) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => SingleReelScreen(reel: item.reel!)));
      return;
    }
    // Постҳо — паймоиш дар байни ҳамаи постҳои ҳамин таб.
    final posts = _items.where((e) => !e.isReel).map((e) => e.post!).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PostDetailScreen(
        posts: posts,
        initialIndex: posts.indexWhere((p) => p.id == item.id).clamp(0, posts.length - 1),
        title: '#${widget.tag}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    }
    if (_error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(tr('hashtag.retry'))),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(tr('hashtag.empty'),
            style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 900) _loadMore();
          return false;
        },
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 1.5, crossAxisSpacing: 1.5,
              childAspectRatio: 0.8),
          itemCount: _items.length,
          itemBuilder: (_, i) => _Cell(item: _items[i], onTap: () => _open(i)),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final HashtagItem item;
  final VoidCallback onTap;
  const _Cell({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final views = item.reel?.viewsCount ?? item.post?.viewsCount ?? 0;
    return GestureDetector(
      key: ValueKey('hashtag-item-${item.id}'),
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        Container(color: AppColors.card),
        VideoFrame(
          thumbUrl: item.isReel || item.post?.mediaType != 'video' ? item.thumbnail : '',
          videoUrl: item.reel?.videoUrl ??
              (item.post?.mediaType == 'video' ? item.post!.mediaUrl : ''),
          fit: BoxFit.cover,
        ),
        if (item.isReel)
          Positioned(
            top: 6, right: 6,
            child: SvgPicture.asset('assets/icons/nav_reels.svg',
                width: 16, height: 16,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          )
        else if (item.isMulti)
          const Positioned(
            top: 6, right: 6,
            child: Icon(AppIcons.collections_rounded, color: Colors.white, size: 16,
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)]),
          ),
        if (views > 0)
          Positioned(
            bottom: 5, left: 5,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(AppIcons.remove_red_eye_rounded, color: Colors.white, size: 11,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
              const SizedBox(width: 3),
              Text(compactCount(views),
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
            ]),
          ),
      ]),
    );
  }
}
