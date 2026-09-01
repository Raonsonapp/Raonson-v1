// lib/promote/my_promotions_screen.dart
// «Рекламаҳои ман» — рӯйхати фармоишҳои реклама бо ҳолат ва омор.
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

class MyPromotionsScreen extends StatefulWidget {
  const MyPromotionsScreen({super.key});
  @override
  State<MyPromotionsScreen> createState() => _MyPromotionsScreenState();
}

class _MyPromotionsScreenState extends State<MyPromotionsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/promotions/');
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        final list = (body['promotions'] as List?) ?? [];
        _items = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String id) async {
    try {
      await ApiClient.instance.delete('/promotions/$id');
      setState(() => _items.removeWhere((e) => e['id'] == id));
    } catch (_) {}
  }

  ({String label, Color color}) _status(String s) {
    switch (s) {
      case 'active':   return (label: tr('ui.c0f3d3d6f3'), color: AppColors.storyEnd);
      case 'finished': return (label: tr('ui.ea849e43d2'), color: AppColors.textFaint);
      case 'rejected': return (label: tr('ui.c428be389c'), color: Colors.redAccent);
      default:         return (label: tr('ui.acb9082e78'), color: Colors.orangeAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(tr('ui.66611b7212'),
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.storyEnd))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Шумо ҳоло рекламае насохтаед.\n'
                      'Дар ҳар пости худ «Тарғиб кардан»-ро пахш кунед.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textTertiary, height: 1.5),
                    ),
                  ))
              : RefreshIndicator(
                  color: AppColors.storyEnd,
                  backgroundColor: AppColors.card,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(_items[i]),
                  ),
                ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final st    = _status((p['status'] ?? '').toString());
    final thumb = (p['thumb'] ?? '').toString();
    final budget = ((p['budgetCents'] ?? 0) as num) / 100;
    final days   = p['durationDays'] ?? 0;
    final impr   = p['impressions'] ?? 0;
    final clicks = p['clicks'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerFaint),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb.isNotEmpty
                ? CachedNetworkImage(imageUrl: thumb, width: 52, height: 52,
                    fit: BoxFit.cover, memCacheWidth: 104,
                    errorWidget: (_, __, ___) => _ph())
                : _ph(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: st.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(st.label,
                        style: TextStyle(color: st.color,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(tr('promote.budgetPerDay',
                        {'budget': budget.toStringAsFixed(0), 'days': days}),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(AppIcons.delete_outline, color: AppColors.textFaint),
            onPressed: () => _delete((p['id'] ?? '').toString()),
          ),
        ]),
        Divider(color: AppColors.dividerFaint, height: 20),
        Row(children: [
          _stat('Намоишҳо', '$impr'),
          _stat('Кликҳо', '$clicks'),
          _stat('CTR', impr == 0
              ? '0%'
              : '${((clicks / (impr as num)) * 100).toStringAsFixed(1)}%'),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: AppColors.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              color: AppColors.textTertiary, fontSize: 11)),
        ]),
      );

  Widget _ph() => Container(width: 52, height: 52,
      color: AppColors.card,
      child: Icon(AppIcons.image_outlined, color: AppColors.textFaint));
}
