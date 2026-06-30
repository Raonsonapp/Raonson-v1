// lib/news/news_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

class NewsItem {
  final String title, link, description, image, source, pubDate;
  NewsItem({
    required this.title, required this.link, required this.description,
    required this.image, required this.source, required this.pubDate,
  });
  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        title: (j['title'] ?? '').toString(),
        link: (j['link'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        image: (j['image'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        pubDate: (j['pubDate'] ?? '').toString(),
      );

  String get timeAgo {
    final t = DateTime.tryParse(pubDate);
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
  List<NewsItem> _news = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiClient.instance.get('/news')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final body = jsonDecode(r.body);
        final list = (body['news'] ?? []) as List;
        _news = list
            .map((e) => NewsItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } else {
        _error = 'Ахбор бор нашуд';
      }
    } catch (_) {
      _error = 'Ахбор бор нашуд';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(NewsItem n) async {
    if (n.link.isEmpty) return;
    try {
      await launchUrl(Uri.parse(n.link), mode: LaunchMode.externalApplication);
    } catch (_) {}
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
                  TextButton(onPressed: _load, child: const Text('Аз нав')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _news.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: AppColors.dividerFaint, height: 1),
                    itemBuilder: (_, i) => _tile(_news[i]),
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
