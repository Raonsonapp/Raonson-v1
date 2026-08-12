// lib/settings/seller_dashboard_screen.dart
// Панели фурӯши магоза — фурӯш, даромад, комиссия, махсули беҳтарин, боздидҳо.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../shop/order_management_screen.dart';
import '../shop/crm_screen.dart';
import '../shop/promo_codes_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboardScreen> {
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
      final r = await ApiClient.instance.get('/shop/insights')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        _data = jsonDecode(r.body) as Map<String, dynamic>;
      } else {
        _error = 'Омори магоза бор нашуд';
      }
    } catch (_) {
      _error = 'Омори магоза бор нашуд';
    }
    if (mounted) setState(() => _loading = false);
  }

  int _i(String k) => (_data?[k] as num?)?.toInt() ?? 0;
  double _d(String k) => (_data?[k] as num?)?.toDouble() ?? 0;
  String get _cur => (_data?['currency'] ?? 'TJS').toString();
  String _money(double v) =>
      '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} $_cur';
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
        title: Text('Магозаи ман',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? _DashSkeleton()
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
                      Text('30 рӯзи охир',
                          style: TextStyle(color: AppColors.textFaint,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _revenueCard(),
                      const SizedBox(height: 12),
                      Row(children: [
                        _tile('🛒', _fmt(_i('salesCount30d')), 'Фурӯшҳо'),
                        _tile('📦', _fmt(_i('productsCount')), 'Махсулот'),
                        _tile('👁', _fmt(_i('viewsTotal')), 'Боздидҳо'),
                      ]),
                      const SizedBox(height: 16),
                      // Идоракунӣ — Фармоишҳо ва Муштариён (CRM)
                      Row(children: [
                        _action('📦', 'Фармоишҳо', 'Идоракунии ҳолат',
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const OrderManagementScreen()))),
                        const SizedBox(width: 10),
                        _action('👥', 'Муштариён', 'CRM ва таърих',
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const CrmScreen()))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _action('🏷️', 'Промокодҳо', 'Тахфиф ва купон',
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const PromoCodesScreen()))),
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox()),
                      ]),
                      const SizedBox(height: 20),
                      _topProducts(),
                      _dailyChart(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _revenueCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF00E87A), Color(0xFF00A860)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Даромади умумӣ',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Text(_money(_d('revenue30d')),
            style: const TextStyle(color: Colors.white,
                fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(AppIcons.info_outline_rounded, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text('Комиссияи Raonson (5%): ${_money(_d('commission30d'))}',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _action(String emoji, String title, String sub, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 14)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
            ])),
        ]),
      ),
    ));
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

  Widget _topProducts() {
    final list = (_data?['topProducts'] as List?) ?? [];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Column(children: [
          Icon(AppIcons.storefront_rounded, color: AppColors.textFaint, size: 40),
          const SizedBox(height: 10),
          Text('Ҳанӯз фурӯш нест',
              style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
          Text('Махсулот эълон кунед ва фурӯшро оғоз намоед',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        ])),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Махсули беҳтарин',
          style: TextStyle(color: AppColors.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      ...list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        final name = (m['name'] ?? '').toString();
        final thumb = (m['thumb'] ?? '').toString();
        final sold = (m['sold'] as num?)?.toInt() ?? 0;
        final revenue = (m['revenue'] as num?)?.toDouble() ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumb.isNotEmpty
                  ? CachedNetworkImage(imageUrl: thumb,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(width: 48, height: 48, color: AppColors.card))
                  : Container(width: 48, height: 48, color: AppColors.card,
                      child: Icon(AppIcons.storefront_rounded,
                          color: AppColors.textFaint, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Махсул' : name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              Text('$sold фурӯш',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ])),
            Text(_money(revenue),
                style: TextStyle(color: const Color(0xFF00E87A),
                    fontWeight: FontWeight.w700)),
          ]),
        );
      }),
      const SizedBox(height: 20),
    ]);
  }

  Widget _dailyChart() {
    final list = (_data?['dailySales'] as List?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    // Ҳадди аксар барои миқёс
    int maxCount = 1;
    for (final e in list) {
      final c = ((e as Map)['count'] as num?)?.toInt() ?? 0;
      if (c > maxCount) maxCount = c;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Фурӯш аз рӯи рӯз',
          style: TextStyle(color: AppColors.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: list.map<Widget>((e) {
            final m = (e as Map).cast<String, dynamic>();
            final c = (m['count'] as num?)?.toInt() ?? 0;
            final h = (c / maxCount) * 100;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: h < 4 ? 4 : h,
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ));
          }).toList(),
        ),
      ),
      const SizedBox(height: 6),
      Text('Ҳар сутун = 1 рӯз (30 рӯзи охир)',
          style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
      const SizedBox(height: 20),
    ]);
  }
}

class _DashSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.divider,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 14, width: 100,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 16),
          for (int i = 0; i < 3; i++) ...[
            Container(height: 80,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(14))),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Container(height: 14, width: 130,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 12),
          Container(height: 140,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14))),
        ],
      ),
    );
  }
}
