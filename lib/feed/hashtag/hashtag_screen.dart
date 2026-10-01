import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../app/app_theme.dart';
import '../../models/post_model.dart';
import '../post/post_card.dart';
import '../../core/ui/app_icons.dart';
import '../../core/i18n/strings.dart';

class HashtagScreen extends StatefulWidget {
  final String hashtag; // бе # аломат
  const HashtagScreen({super.key, required this.hashtag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<PostModel> _posts = [];
  bool _loading = true;
  String? _error;
  // Сервер 24-тоӣ медиҳад. Пеш танҳо 24 пости охирини ҳаштаг дида мешуд.
  static const _pageSize = 24;
  bool _hasMore = false, _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<PostModel>> _page(int page) async {
    final res = await ApiClient.instance
        .get('/posts/hashtag/${Uri.encodeComponent(widget.hashtag)}',
            query: {'page': '$page', 'limit': '$_pageSize'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw Exception('Хато ${res.statusCode}');
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['posts'] ?? []) as List;
    return list
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final posts = await _page(1);
      if (mounted) {
        setState(() {
          _posts = posts;
          _hasMore = posts.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      // Матни истисно («TimeoutException after 0:00:10…») ба корбар
      // маъное надорад.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('#${widget.hashtag}',
          style: TextStyle(color: AppColors.textPrimary,
              fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _loading
          ? Shimmer.fromColors(
              baseColor: AppColors.card,
              highlightColor: AppColors.divider,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                itemCount: 15,
                itemBuilder: (_, __) => Container(color: Colors.white),
              ),
            )
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.error_outline, color: AppColors.textFaint, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.textFaint)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonBlue),
                    child: Text(tr('ui.fa5607ad24')),
                  ),
                ]))
              : _posts.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(AppIcons.tag, color: AppColors.dividerFaint, size: 64),
                      const SizedBox(height: 12),
                      Text('#${widget.hashtag}',
                        style: TextStyle(color: AppColors.textFaint,
                            fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(tr('ui.7f3e23b624'),
                        style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
                    ]))
                  : RefreshIndicator(
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
                          itemCount: _posts.length,
                          itemBuilder: (_, i) =>
                              PostCard(key: ValueKey(_posts[i].id), post: _posts[i]),
                        ),
                      ),
                    ),
    );
  }
}
