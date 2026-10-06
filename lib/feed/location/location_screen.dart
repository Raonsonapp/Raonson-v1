import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/places/place.dart';
import '../../core/ui/app_icons.dart';
import '../../models/post_model.dart';
import '../post/post_card.dart';

/// Саҳифаи ҷой — мисли Instagram: ҳамаи постҳои кушода бо ҳамин ҷой.
///
/// [placeId] — ҷой аз рӯйхат (/places/:id/posts). Агар холӣ бошад (пости
/// кӯҳна ё ҷойи дастӣ) — аз рӯи матн (/places/text/posts?name=); агар
/// сервер матнро ба ҷойи рӯйхат мувофиқ донад, ба саҳифаи пурра мегузарад.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<PostModel>> _page(int page) async {
    final q = {
      'page': '$page',
      'limit': '$_pageSize',
      'lang': AppSettingsState.instance.lang,
    };
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

  Widget _headerCard() {
    final title = _place?.name ?? widget.name;
    final region = _place?.region ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.error_outline, color: AppColors.textFaint, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: AppColors.textFaint)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue),
            child: Text(tr('place.retry')),
          ),
        ]),
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.neonBlue,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 1200) _loadMore();
            return false;
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _posts.isEmpty ? 2 : _posts.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _headerCard();
              if (_posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(tr('place.postsEmpty'),
                        style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
                  ),
                );
              }
              final p = _posts[i - 1];
              return PostCard(key: ValueKey(p.id), post: p);
            },
          ),
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
        title: Text(_place?.name ?? widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: body,
    );
  }
}
