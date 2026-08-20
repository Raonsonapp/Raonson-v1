// lib/shop/orders_screen.dart
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/tajikshop_brand.dart';
import 'shop_repository.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ShopRepository();
  late final TabController _tab;
  List<Map<String, dynamic>> _buying = [], _selling = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final b = await _repo.myOrders();
    final s = await _repo.sellingOrders();
    if (!mounted) return;
    setState(() {
      _buying = b;
      _selling = s;
      _loading = false;
    });
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
          Text(' — Фармоишҳо',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        ]),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textFaint,
          indicatorColor: AppColors.neonBlue,
          tabs: const [Tab(text: 'Харидҳои ман'), Tab(text: 'Фурӯшҳои ман')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : TabBarView(
              controller: _tab,
              children: [
                _list(_buying, 'seller'),
                _list(_selling, 'buyer'),
              ],
            ),
    );
  }

  Widget _list(List<Map<String, dynamic>> orders, String party) {
    if (orders.isEmpty) {
      return Center(
          child: Text('Ҳанӯз фармоиш нест',
              style: TextStyle(color: AppColors.textFaint)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (_, __) =>
            Divider(color: AppColors.dividerFaint, height: 1),
        itemBuilder: (_, i) {
          final o = orders[i];
          final other = (o[party] ?? {}) as Map;
          final price = (o['price'] as num?)?.toDouble() ?? 0;
          final commission = (o['commission'] as num?)?.toDouble() ?? 0;
          final cur = (o['currency'] ?? 'TJS').toString();
          return ListTile(
            leading: Icon(AppIcons.card_giftcard_rounded,
                color: AppColors.neonBlue),
            title: Text((o['productName'] ?? 'Маҳсулот').toString(),
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
                '${(other['username'] ?? '').toString()} · '
                '${(o['status'] ?? 'pending').toString()}',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${price.toStringAsFixed(0)} $cur',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                if (party == 'buyer')
                  Text('комиссия ${commission.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: AppColors.textFaint, fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }
}
