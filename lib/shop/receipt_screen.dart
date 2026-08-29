// lib/shop/receipt_screen.dart
// Чек/Invoice-и фармоиш — аз маълумоти воқеии backend (/orders/selling).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import 'order_management_screen.dart' show kOrderStatuses;
import '../core/i18n/strings.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const ReceiptScreen({super.key, required this.order});

  String get _id => (order['id'] ?? order['_id'] ?? '').toString();
  double get _amount => (order['amount'] as num?)?.toDouble() ?? 0;
  double get _commission => (order['commission'] as num?)?.toDouble() ?? 0;
  String get _currency => (order['currency'] ?? 'сом').toString();
  String get _status => (order['status'] ?? 'pending').toString();

  String _money(double v) =>
      '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} $_currency';

  String _date() {
    final t = DateTime.tryParse((order['createdAt'] ?? '').toString());
    if (t == null) return '';
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  String _asText() {
    final p = (order['product'] ?? {}) as Map;
    final b = (order['buyer'] ?? {}) as Map;
    return '🧾 RAONSON — Чеки фармоиш\n'
        '№ ${_id.length > 8 ? _id.substring(0, 8) : _id}\n'
        'Сана: ${_date()}\n'
        'Маҳсул: ${p['productName'] ?? '-'}\n'
        'Харидор: @${b['username'] ?? '-'}\n'
        'Нарх: ${_money(_amount)}\n'
        'Комиссия (5%): ${_money(_commission)}\n'
        'Ҳолат: ${kOrderStatuses[_status]?.label ?? _status}';
  }

  @override
  Widget build(BuildContext context) {
    final p = (order['product'] ?? {}) as Map;
    final b = (order['buyer'] ?? {}) as Map;
    final st = kOrderStatuses[_status];
    final thumb = (p['image'] ?? '').toString();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ui.29effce436'),
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(AppIcons.copy_rounded, color: AppColors.textPrimary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _asText()));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('ui.cdd092966b'))));
            },
          ),
          IconButton(
            icon: Icon(AppIcons.share_outlined, color: AppColors.textPrimary),
            onPressed: () => Share.share(_asText()),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Center(child: Column(children: [
            Text('RAONSON', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 22,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text(tr('ui.69afb85aa5'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ])),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card,
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(imageUrl: thumb,
                          width: 60, height: 60, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              width: 60, height: 60, color: AppColors.surface))
                      : Container(width: 60, height: 60, color: AppColors.surface,
                          child: Icon(AppIcons.storefront_rounded,
                              color: AppColors.textFaint)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text((p['productName'] ?? 'Маҳсул').toString(),
                    style: TextStyle(color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700, fontSize: 15))),
                if (st != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: st.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(st.label, style: TextStyle(color: st.color,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 16),
              Divider(color: AppColors.dividerFaint),
              _row('Рақами фармоиш',
                  '№ ${_id.length > 8 ? _id.substring(0, 8) : _id}'),
              _row('Сана', _date()),
              _row('Харидор', '@${b['username'] ?? '-'}'),
              Divider(color: AppColors.dividerFaint),
              _row('Нарх', _money(_amount)),
              _row('Комиссияи Raonson (5%)', _money(_commission)),
              const SizedBox(height: 6),
              _row('Даромади холиси шумо',
                  _money(_amount - _commission), bold: true),
            ]),
          ),
          const SizedBox(height: 16),
          Center(child: Text(tr('ui.a987f80582'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
        Text(value, style: TextStyle(
            color: bold ? const Color(0xFF00C853) : AppColors.textPrimary,
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }
}
