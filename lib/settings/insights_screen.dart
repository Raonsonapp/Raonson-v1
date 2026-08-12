// lib/settings/insights_screen.dart
// Омори 1-моҳаи корбар — обуна, лайк, топ видео/пост, идеяҳо (мисли Instagram Insights).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? _data;
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
      final r = await ApiClient.instance.get('/profile/insights')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        _data = jsonDecode(r.body) as Map<String, dynamic>;
      } else {
        _error = 'Омор бор нашуд';
      }
    } catch (_) {
      _error = 'Омор бор нашуд';
    }
    if (mounted) setState(() => _loading = false);
  }

  int _i(String k) => (_data?[k] as num?)?.toInt() ?? 0;
  double _d(String k) => (_data?[k] as num?)?.toDouble() ?? 0;
  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
            icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text('Статистика',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? _InsightsSkeleton()
          : (_error != null)
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: TextStyle(color: AppColors.textFaint)),
                  TextButton(onPressed: _load, child: const Text('Аз нав')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Обзори 30 рӯзи охир',
                          style: TextStyle(color: AppColors.textFaint,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      // Growth card
                      _growthCard(),
                      const SizedBox(height: 12),
                      // Stat tiles
                      Row(children: [
                        _tile('👁', _fmt(_i('views30d')), 'Кӯринишҳо'),
                        _tile('❤️', _fmt(_i('likes30d')), 'Лайкҳо'),
                        _tile('💬', _fmt(_i('comments30d')), 'Шарҳҳо'),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _tile('📸', _fmt(_i('postsCount')), 'Постҳо'),
                        _tile('🎬', _fmt(_i('reelsCount')), 'Reels'),
                        _tile('👥', _fmt(_i('followersNow')), 'Обуначиён'),
                      ]),
                      const SizedBox(height: 20),
                      _topSection('Топ постҳо', _data?['topPosts'], false),
                      _topSection('Топ Reels', _data?['topReels'], true),
                      _ideasSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _growthCard() {
    final gained = _i('followersGained30d');
    final pct = _d('growthPct');
    final up = gained >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Пешрафти обуначиён',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('${up ? '+' : ''}$gained',
              style: const TextStyle(color: Colors.white,
                  fontSize: 30, fontWeight: FontWeight.w800)),
          Text('дар 30 рӯз', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        const Spacer(),
        Column(children: [
          Icon(up ? AppIcons.trending_up_rounded : AppIcons.trending_down_rounded,
              color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text('${pct.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _tile(String emoji, String value, String label) {
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.card,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: AppColors.textPrimary,
            fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
      ]),
    ));
  }

  Widget _topSection(String title, dynamic listRaw, bool isReel) {
    final list = (listRaw as List?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: AppColors.textPrimary,
          fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final m = (list[i] as Map).cast<String, dynamic>();
            final thumb = (m['thumb'] ?? '').toString();
            final likes = (m['likes'] as num?)?.toInt() ?? 0;
            final views = (m['views'] as num?)?.toInt() ?? 0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(children: [
                thumb.isNotEmpty
                    ? CachedNetworkImage(imageUrl: thumb,
                        width: 110, height: 150, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(width: 110, color: AppColors.card))
                    : Container(width: 110, height: 150, color: AppColors.card),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    color: Colors.black54,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isReel ? AppIcons.remove_red_eye_rounded
                                  : AppIcons.favorite_rounded,
                          fill: 1, color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(_fmt(isReel ? views : likes),
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ]),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }

  Widget _ideasSection() {
    final ideas = (_data?['ideas'] as List?) ?? [];
    if (ideas.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(AppIcons.bolt_rounded, color: const Color(0xFFFFD700), size: 18),
        const SizedBox(width: 6),
        Text('Идеяҳои нав (тренд)',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      Text('Мавзӯъҳое, ки ҳозир машҳуранд — барои видеои навбатии шумо.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: ideas.map((e) {
        final tag = e.toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.card,
              borderRadius: BorderRadius.circular(20)),
          child: Text(tag.startsWith('#') ? tag : '#$tag',
              style: TextStyle(color: AppColors.neonBlue,
                  fontSize: 13, fontWeight: FontWeight.w600)),
        );
      }).toList()),
    ]);
  }
}

class _InsightsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.divider,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 14, width: 120,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 16),
          for (int i = 0; i < 4; i++) ...[
            Container(height: 72,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(14))),
            const SizedBox(height: 12),
          ],
          Container(height: 14, width: 100,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 12),
          Row(children: [
            for (int i = 0; i < 3; i++) ...[
              Expanded(child: Container(height: 90,
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(10)))),
              if (i < 2) const SizedBox(width: 8),
            ],
          ]),
        ],
      ),
    );
  }
}
