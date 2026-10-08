import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/places/place.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/video_frame.dart';
import '../../models/post_model.dart';
import '../../models/reel_model.dart';
import '../../reels/single_reel_screen.dart';
import '../post/post_card.dart';

/// Саҳифаи ҷой — мисли Instagram: ду таб, «Постҳо» ва «Reels», бо ҳамаи
/// мундариҷаи кушода бо ҳамин ҷой.
///
/// [placeId] — ҷой аз рӯйхат (/places/:id/posts|reels). Агар холӣ бошад
/// (пости кӯҳна ё ҷойи дастӣ) — аз рӯи матн (/places/text/posts|reels);
/// агар сервер матнро ба ҷойи рӯйхат мувофиқ донад, ба саҳифаи пурра
/// мегузарад.
class LocationScreen extends StatefulWidget {
  final String placeId;
  final String name;
  const LocationScreen({super.key, this.placeId = '', required this.name});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  static const _pageSize = 24;
  late String _placeId = widget.placeId;
  Place? _place;
  List<PostModel> _posts = [];
  bool _loading = true, _hasMore = false, _loadingMore = false;
  String? _error;

  // ── Reels ──
  List<ReelModel> _reels = [];
  bool _reelsLoading = true, _reelsHasMore = false, _reelsLoadingMore = false;
  String? _reelsError;

  @override
  void initState() {
    super.initState();
    _load().then((_) => _loadReels());
  }

  Map<String, String> _q(int page) => {
        'page': '$page',
        'limit': '$_pageSize',
        'lang': AppSettingsState.instance.lang,
      };

  Future<List<PostModel>> _page(int page) async {
    final q = _q(page);
    final res = _placeId.isNotEmpty
        ? await ApiClient.instance
            .get('/places/${Uri.encodeComponent(_placeId)}/posts', query: q)
            .timeout(const Duration(seconds: 10))
        : await ApiClient.instance
            .get('/places/text/posts', query: {...q, 'name': widget.name})
            .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final p = body['place'];
    if (p is Map) {
      final place = Place.fromJson(Map<String, dynamic>.from(p));
      if (_placeId.isEmpty && place.id.isNotEmpty) {
        // Матн ба ҷойи рӯйхат мувофиқ аст — саҳифаи пурра (бо постҳои
        // нав, ки id доранд).
        _placeId = place.id;
        _place = place;
        return _page(page);
      }
      _place = place;
    }
    return (body['posts'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PostModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ReelModel>> _reelPage(int page) async {
    final q = _q(page);
    final res = _placeId.isNotEmpty
        ? await ApiClient.instance
            .get('/places/${Uri.encodeComponent(_placeId)}/reels', query: q)
            .timeout(const Duration(seconds: 10))
        : await ApiClient.instance
            .get('/places/text/reels', query: {...q, 'name': widget.name})
            .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['reels'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ReelModel.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final posts = await _page(1);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _hasMore = posts.length >= _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _error = tr('common.noConnection'); });
      }
    }
  }

  Future<void> _loadReels() async {
    if (mounted) setState(() { _reelsLoading = true; _reelsError = null; });
    try {
      final reels = await _reelPage(1);
      if (!mounted) return;
      setState(() {
        _reels = reels;
        _reelsHasMore = reels.length >= _pageSize;
        _reelsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _reelsLoading = false;
          _reelsError = tr('common.noConnection');
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    _loadingMore = true;
    try {
      final page = await _page(_posts.length ~/ _pageSize + 1);
      if (!mounted) return;
      final seen = _posts.map((p) => p.id).toSet();
      final fresh = page.where((p) => seen.add(p.id)).toList();
      setState(() {
        _posts = [..._posts, ...fresh];
        _hasMore = page.length >= _pageSize && fresh.isNotEmpty;
      });
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _loadMoreReels() async {
    if (!_reelsHasMore || _reelsLoadingMore || _reelsLoading) return;
    _reelsLoadingMore = true;
    try {
      final page = await _reelPage(_reels.length ~/ _pageSize + 1);
      if (!mounted) return;
      final seen = _reels.map((r) => r.id).toSet();
      final fresh = page.where((r) => seen.add(r.id)).toList();
      setState(() {
        _reels = [..._reels, ...fresh];
        _reelsHasMore = page.length >= _pageSize && fresh.isNotEmpty;
      });
    } catch (_) {
    } finally {
      _reelsLoadingMore = false;
    }
  }

  Widget _headerCard() {
    final title = _place?.name ?? widget.name;
    final region = _place?.region ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(AppIcons.location_on, color: AppColors.red, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            if (region.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(region,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _errorView(String msg, VoidCallback retry) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.error_outline, color: AppColors.textFaint, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: AppColors.textFaint)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: retry,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue),
            child: Text(tr('place.retry')),
          ),
        ]),
      );

  Widget _empty(String text) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text(text,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
            ),
          ),
        ],
      );

  Widget _postsTab() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    }
    if (_error != null) return _errorView(_error!, _load);
    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: _posts.isEmpty
          ? _empty(tr('place.postsEmpty'))
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 1200) _loadMore();
                return false;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _posts.length,
                itemBuilder: (_, i) {
                  final p = _posts[i];
                  return PostCard(key: ValueKey(p.id), post: p);
                },
              ),
            ),
    );
  }

  Widget _reelsTab() {
    if (_reelsLoading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    }
    if (_reelsError != null) return _errorView(_reelsError!, _loadReels);
    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: _loadReels,
      child: _reels.isEmpty
          ? _empty(tr('place.reelsEmpty'))
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 800) _loadMoreReels();
                return false;
              },
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: _reels.length,
                itemBuilder: (_, i) {
                  final r = _reels[i];
                  return GestureDetector(
                    key: ValueKey('place-reel-${r.id}'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SingleReelScreen(reel: r))),
                    child: Stack(fit: StackFit.expand, children: [
                      VideoFrame(thumbUrl: r.thumbnailUrl, videoUrl: r.videoUrl),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Row(children: [
                          const Icon(AppIcons.play_arrow_rounded,
                              color: Colors.white, size: 16),
                          Text('${r.viewsCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black)
                                  ])),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back_ios_new, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(_place?.name ?? widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ),
        body: Column(children: [
          _headerCard(),
          TabBar(
            indicatorColor: AppColors.textPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: [
              Tab(text: tr('place.tabPosts')),
              Tab(text: tr('place.tabReels')),
            ],
          ),
          Expanded(
            child: TabBarView(children: [_postsTab(), _reelsTab()]),
          ),
        ]),
      ),
    );
  }
}
