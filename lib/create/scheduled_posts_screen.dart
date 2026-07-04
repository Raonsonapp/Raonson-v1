// lib/create/scheduled_posts_screen.dart
// Постҳои ба нақша гирифташуда (Pro) — рӯйхат аз /posts/scheduled.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';

class ScheduledPostsScreen extends StatefulWidget {
  const ScheduledPostsScreen({super.key});
  @override
  State<ScheduledPostsScreen> createState() => _ScheduledPostsState();
}

class _ScheduledPostsState extends State<ScheduledPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/posts/scheduled')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body);
        final list = (b['posts'] ?? []) as List;
        _posts = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _when(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} · ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Постҳои ба нақша',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _posts.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.schedule_rounded,
                      color: AppColors.textFaint, size: 44),
                  const SizedBox(height: 10),
                  Text('Пости ба нақша гирифташуда нест',
                      style: TextStyle(color: AppColors.textFaint)),
                  const SizedBox(height: 4),
                  Text('Ҳангоми нашр «Ба нақша гирифтан»-ро интихоб кунед',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _posts.length,
                    itemBuilder: (_, i) {
                      final p = _posts[i];
                      final media = (p['media'] as List?) ?? [];
                      final thumb = media.isNotEmpty
                          ? ((media.first as Map)['url'] ?? '').toString() : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.card,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumb.isNotEmpty
                                ? CachedNetworkImage(imageUrl: thumb,
                                    width: 56, height: 56, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                        width: 56, height: 56, color: AppColors.surface))
                                : Container(width: 56, height: 56,
                                    color: AppColors.surface,
                                    child: Icon(AppIcons.image_outlined,
                                        color: AppColors.textFaint)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(AppIcons.schedule_rounded,
                                    color: const Color(0xFFE100FF), size: 13),
                                const SizedBox(width: 4),
                                Text(_when((p['scheduledAt'] ?? '').toString()),
                                    style: const TextStyle(color: Color(0xFFE100FF),
                                        fontSize: 12, fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 4),
                              Text((p['caption'] ?? '').toString().isEmpty
                                      ? 'Бе тавсиф'
                                      : (p['caption']).toString(),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ])),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
