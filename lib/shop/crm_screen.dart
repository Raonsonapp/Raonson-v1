// lib/shop/crm_screen.dart
// CRM — рӯйхати муштариён (аз фармоишҳо ҷамъбаст).
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../widgets/avatar.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});
  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/shop/customers')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body);
        final list = (b['customers'] ?? []) as List;
        _customers = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _money(double v) =>
      '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} сом';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Муштариён (CRM)',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _customers.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.people_outline_rounded,
                      color: AppColors.textFaint, size: 44),
                  const SizedBox(height: 10),
                  Text('Ҳанӯз муштарӣ нест',
                      style: TextStyle(color: AppColors.textFaint)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _customers.length,
                    itemBuilder: (_, i) {
                      final c = _customers[i];
                      final count = (c['ordersCount'] as num?)?.toInt() ?? 0;
                      final spent = (c['totalSpent'] as num?)?.toDouble() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.card,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          if (i < 3)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(['🥇', '🥈', '🥉'][i],
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          Avatar(imageUrl: (c['avatar'] ?? '').toString(),
                              size: 42, name: (c['username'] ?? '').toString()),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@${c['username'] ?? 'муштарӣ'}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              Text('$count фармоиш',
                                  style: TextStyle(color: AppColors.textFaint,
                                      fontSize: 12)),
                            ])),
                          Text(_money(spent),
                              style: TextStyle(color: const Color(0xFF00C853),
                                  fontWeight: FontWeight.w700)),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
