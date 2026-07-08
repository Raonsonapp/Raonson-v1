// lib/shop/order_management_screen.dart
// Идоракунии фармоишҳо барои фурӯшанда — тағйири ҳолат (Pending → Delivered ...).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../widgets/avatar.dart';
import 'receipt_screen.dart';

const Map<String, ({String label, Color color})> kOrderStatuses = {
  'pending':   (label: 'Дар интизор',    color: Color(0xFFF7971E)),
  'confirmed': (label: 'Тасдиқшуда',      color: Color(0xFF00C6FF)),
  'packed':    (label: 'Бастабандӣ',      color: Color(0xFF7F00FF)),
  'shipping':  (label: 'Дар роҳ',         color: Color(0xFF00A8E8)),
  'delivered': (label: 'Расонида шуд',    color: Color(0xFF00C853)),
  'returned':  (label: 'Баргардонида',    color: Color(0xFF9E9E9E)),
  'refunded':  (label: 'Пул баргашт',     color: Color(0xFF9E9E9E)),
  'cancelled': (label: 'Бекоршуда',       color: Color(0xFFE53935)),
};

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});
  @override
  State<OrderManagementScreen> createState() => _OrderManagementState();
}

class _OrderManagementState extends State<OrderManagementScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/orders/selling')
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body);
        final list = (b['orders'] ?? []) as List;
        _orders = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(Map<String, dynamic> o, String status) async {
    final id = (o['id'] ?? o['_id'] ?? '').toString();
    if (id.isEmpty) return;
    final prev = (o['status'] ?? 'pending').toString();
    setState(() => o['status'] = status);
    try {
      final r = await ApiClient.instance
          .put('/orders/$id/status', body: {'status': status});
      if (r.statusCode >= 400 && mounted) setState(() => o['status'] = prev);
    } catch (_) { if (mounted) setState(() => o['status'] = prev); }
  }

  void _pickStatus(Map<String, dynamic> o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text('Ҳолати фармоиш',
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          ...kOrderStatuses.entries.map((e) => ListTile(
            leading: Container(width: 12, height: 12,
                decoration: BoxDecoration(color: e.value.color,
                    shape: BoxShape.circle)),
            title: Text(e.value.label,
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _setStatus(o, e.key); },
          )),
          const SizedBox(height: 12),
        ])),
    );
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'all'
      ? _orders
      : _orders.where((o) => (o['status'] ?? 'pending') == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Фармоишҳо',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: SizedBox(height: 46, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('all', 'Ҳама'),
              ...kOrderStatuses.entries.map((e) => _chip(e.key, e.value.label)),
            ],
          )),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              child: _filtered.isEmpty
                  // Холӣ ҳам scroll мешавад — то pull-to-refresh кор кунад.
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 180),
                        Center(child: Text('Фармоиш нест',
                            style: TextStyle(color: AppColors.textFaint))),
                      ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _orderCard(_filtered[i]),
                    ),
            ),
    );
  }

  Widget _chip(String key, String label) {
    final sel = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppColors.neonBlue : AppColors.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(
              color: sel ? Colors.white : AppColors.textSecondary,
              fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = (o['status'] ?? 'pending').toString();
    final st = kOrderStatuses[status] ??
        (label: status, color: AppColors.textFaint);
    final buyer = (o['buyer'] ?? {}) as Map;
    final product = (o['product'] ?? {}) as Map;
    final amount = (o['amount'] as num?)?.toDouble() ?? 0;
    final thumb = (product['image'] ?? '').toString();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReceiptScreen(order: o))),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card,
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb.isNotEmpty
                ? CachedNetworkImage(imageUrl: thumb,
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(width: 50, height: 50, color: AppColors.surface))
                : Container(width: 50, height: 50, color: AppColors.surface,
                    child: Icon(AppIcons.storefront_rounded,
                        color: AppColors.textFaint, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((product['productName'] ?? 'Маҳсул').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} сом',
                  style: TextStyle(color: const Color(0xFF00C853),
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Avatar(imageUrl: (buyer['avatar'] ?? '').toString(),
              size: 26, name: (buyer['username'] ?? '').toString()),
          const SizedBox(width: 8),
          Expanded(child: Text('@${buyer['username'] ?? 'муштарӣ'}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          GestureDetector(
            onTap: () => _pickStatus(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: st.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: st.color.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(st.label, style: TextStyle(color: st.color,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(AppIcons.keyboard_arrow_down_rounded,
                    color: st.color, size: 16),
              ]),
            ),
          ),
        ]),
      ]),
    ),
    );
  }
}
