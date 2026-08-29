// lib/shop/crm_screen.dart
// CRM — рӯйхати муштариён (аз фармоишҳо ҷамъбаст).
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/tajikshop_brand.dart';
import '../core/api/api_client.dart';
import '../widgets/avatar.dart';
import '../core/i18n/strings.dart';

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

  Future<void> _broadcast() async {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('ui.be2757bada'))));
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(tr('ui.df904489f6'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 4,
          maxLength: 1000,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: tr('ui.7762e0dbc3'),
              hintStyle: TextStyle(color: AppColors.textFaint))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(tr('ui.47ba09d086'), style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(tr('ui.713a3b33c3'), style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok == true && text.isNotEmpty) {
      try {
        final r = await ApiClient.instance.post('/shop/broadcast',
            body: {'text': text});
        if (r.statusCode < 400 && mounted) {
          final sent = (jsonDecode(r.body)['sent'] as num?)?.toInt() ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Паём ба $sent муштарӣ фиристода шуд ✓'),
              backgroundColor: Colors.green));
        }
      } catch (_) {}
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          TajikshopBrand.logoCompact(size: 14),
          Text(' — CRM',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            tooltip: tr('ui.9e7c09d738'),
            icon: Icon(AppIcons.send_rounded, color: AppColors.textPrimary),
            onPressed: _broadcast,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _customers.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.people_outline_rounded,
                      color: AppColors.textFaint, size: 44),
                  const SizedBox(height: 10),
                  Text(tr('ui.be2757bada'),
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
