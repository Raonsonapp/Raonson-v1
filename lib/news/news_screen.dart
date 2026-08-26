// lib/news/news_screen.dart
// Ахбор — Тоҷикистон бештар, баъд СНГ, баъд ҷаҳон. Бо scroll-и беохир,
// филтри забон ва саҳифаи муфассал.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

class NewsItem {
  final String title, link, description, image, source, pubDate, isoDate;
  final String region, lang;
  NewsItem({
    required this.title, required this.link, required this.description,
    required this.image, required this.source, required this.pubDate,
    required this.isoDate, this.region = '', this.lang = '',
  });
  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        title: (j['title'] ?? '').toString(),
        link: (j['link'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        pubDate: (j['pubDate'] ?? '').toString(),
        isoDate: (j['isoDate'] ?? '').toString(),
        region: (j['region'] ?? '').toString(),
        lang: (j['lang'] ?? '').toString(),
      );

  String get timeAgo {
    final t = DateTime.tryParse(isoDate.isNotEmpty ? isoDate : pubDate);
    if (t == null) return source;
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '$source · ${d.inMinutes}д';
    if (d.inHours < 24) return '$source · ${d.inHours}с';
    return '$source · ${d.inDays}р';
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final List<NewsItem> _news = [];
  final _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _lang = 'all';
  String? _error;

  static const _langs = [
    ('all', 'Ҳама'), ('tj', 'Тоҷикӣ'), ('ru', 'Русӣ'), ('en', 'English'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() { _loading = true; _error = null; _page = 1; _hasMore = true; });
    }
    try {
      final r = await ApiClient.instance.get('/news',
              query: {'page': '1', 'limit': '20', 'lang': _lang})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final body = jsonDecode(r.body);
        final list = (body['news'] ?? []) as List;
        _news
          ..clear()
          ..addAll(list.map(
              (e) => NewsItem.fromJson((e as Map).cast<String, dynamic>())));
        _hasMore = body['hasMore'] == true || list.length >= 20;
        _page = 1;
      } else {
        _error = 'Ахбор бор нашуд';
      }
    } catch (_) {
      _error = 'Ахбор бор нашуд';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final next = _page + 1;
    try {
      final r = await ApiClient.instance.get('/news',
              query: {'page': '$next', 'limit': '20', 'lang': _lang})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final body = jsonDecode(r.body);
        final list = (body['news'] ?? []) as List;
        if (list.isEmpty) {
          _hasMore = false;
        } else {
          _news.addAll(list.map(
              (e) => NewsItem.fromJson((e as Map).cast<String, dynamic>())));
          _page = next;
          _hasMore = body['hasMore'] == true || list.length >= 20;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  void _setLang(String l) {
    if (l == _lang) return;
    setState(() => _lang = l);
    _load(reset: true);
  }

  void _open(NewsItem n) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => NewsDetailScreen(item: n)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Ахбор',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _langs.map((l) {
                final sel = l.$1 == _lang;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: GestureDetector(
                    onTap: () => _setLang(l.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.neonBlue : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(l.$2,
                          style: TextStyle(
                              color: sel ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (_error != null && _news.isEmpty)
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.cloud_off_outlined,
                      color: AppColors.textFaint, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.textFaint)),
                  TextButton(onPressed: () => _load(reset: true),
                      child: const Text('Аз нав')),
                ]))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _news.length + 1,
                    separatorBuilder: (_, __) =>
                        Divider(color: AppColors.dividerFaint, height: 1),
                    itemBuilder: (_, i) {
                      if (i >= _news.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: _hasMore
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text('Ин ҳама ахбор',
                                    style: TextStyle(color: AppColors.textFaint,
                                        fontSize: 12)),
                          ),
                        );
                      }
                      return _tile(_news[i]);
                    },
                  ),
                ),
    );
  }

  Widget _tile(NewsItem n) {
    return InkWell(
      onTap: () => _open(n),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (n.region == 'tj')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5)),
                      child: const Text('🇹🇯 Тоҷикистон',
                          style: TextStyle(
                              color: Color(0xFF00C853), fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                Text(n.title,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 15,
                        fontWeight: FontWeight.w600, height: 1.3)),
                if (n.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(n.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 13)),
                ],
                const SizedBox(height: 6),
                Text(n.timeAgo,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
              ],
            ),
          ),
          if (n.image.isNotEmpty) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: n.image,
                width: 92, height: 92, fit: BoxFit.cover,
                memCacheWidth: 276,
                placeholder: (_, __) => Container(
                    width: 92, height: 92, color: AppColors.surface),
                errorWidget: (_, __, ___) => Container(
                    width: 92, height: 92, color: AppColors.surface,
                    child: Icon(AppIcons.image_outlined,
                        color: AppColors.textFaint)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Саҳифаи муфассали ахбор ─────────────────────────────────────────
class NewsDetailScreen extends StatelessWidget {
  final NewsItem item;
  const NewsDetailScreen({super.key, required this.item});

  Future<void> _openLink() async {
    if (item.link.isEmpty) return;
    try {
      await launchUrl(Uri.parse(item.link),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(item.source,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          if (item.image.isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.image,
              width: double.infinity, fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  height: 220, color: AppColors.surface),
              errorWidget: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 21, fontWeight: FontWeight.bold, height: 1.3)),
                const SizedBox(height: 8),
                Text(item.timeAgo,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                const SizedBox(height: 16),
                if (item.description.isNotEmpty)
                  Text(item.description,
                      style: TextStyle(color: AppColors.textSecondary,
                          fontSize: 15, height: 1.6)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _openLink,
                    icon: const Icon(AppIcons.open_in_new_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Хондани пурра',
                        style: TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
          ),
        ],
      ),
    );
  }
}
