// lib/shop/promo_codes_screen.dart
// Промокодҳо/купонҳо барои фурӯшанда — сохтан, рӯйхат, ҳазф.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/tajikshop_brand.dart';
import '../core/api/api_client.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});
  @override
  State<PromoCodesScreen> createState() => _PromoCodesState();
}

class _PromoCodesState extends State<PromoCodesScreen> {
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/shop/promos')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body);
        final list = (b['promos'] ?? []) as List;
        _promos = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String id) async {
    setState(() => _promos.removeWhere((p) => p['id'] == id));
    try { await ApiClient.instance.delete('/shop/promos/$id'); } catch (_) {}
  }

  Future<void> _create() async {
    final codeCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final usesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Промокоди нав',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: 'КОД (мисол: SALE20)',
                hintStyle: TextStyle(color: AppColors.textFaint))),
          TextField(controller: pctCtrl, keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: 'Тахфиф % (1–90)',
                hintStyle: TextStyle(color: AppColors.textFaint))),
          TextField(controller: usesCtrl, keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: 'Лимити истифода (0 = бемаҳдуд)',
                hintStyle: TextStyle(color: AppColors.textFaint))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Сохтан', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    if (ok == true) {
      final code = codeCtrl.text.trim().toUpperCase();
      final pct = int.tryParse(pctCtrl.text.trim()) ?? 0;
      final uses = int.tryParse(usesCtrl.text.trim()) ?? 0;
      if (code.isEmpty || pct < 1 || pct > 90) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Код ва тахфиф (1–90%)-ро дуруст ворид кунед')));
      } else {
        try {
          final r = await ApiClient.instance.post('/shop/promos',
              body: {'code': code, 'discountPct': pct, 'maxUses': uses});
          if (r.statusCode < 400 && mounted) _load();
        } catch (_) {}
      }
    }
    codeCtrl.dispose(); pctCtrl.dispose(); usesCtrl.dispose();
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
          Text(' — Промокодҳо',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.neonBlue,
        onPressed: _create,
        child: Icon(AppIcons.add_circle, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _promos.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.tag_rounded, color: AppColors.textFaint, size: 44),
                  const SizedBox(height: 10),
                  Text('Ҳанӯз промокод нест',
                      style: TextStyle(color: AppColors.textFaint)),
                  Text('Тугмаи + барои сохтан 👇',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _promos.length,
                  itemBuilder: (_, i) {
                    final p = _promos[i];
                    final used = (p['usedCount'] as num?)?.toInt() ?? 0;
                    final maxU = (p['maxUses'] as num?)?.toInt() ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(AppIcons.tag_rounded, color: AppColors.neonBlue),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((p['code'] ?? '').toString(),
                                style: TextStyle(color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800, fontSize: 16,
                                    letterSpacing: 1)),
                            Text('${p['discountPct']}% тахфиф · '
                                'истифода: $used${maxU > 0 ? '/$maxU' : ''}',
                                style: TextStyle(color: AppColors.textFaint,
                                    fontSize: 12)),
                          ])),
                        IconButton(
                          icon: Icon(AppIcons.delete_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _delete((p['id'] ?? '').toString()),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
