// lib/shop/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../widgets/avatar.dart';
import '../models/user_model.dart';
import '../core/services/user_session.dart';
import '../app/app_settings.dart';
import '../chat/room/chat_room_screen.dart';
import 'shop_repository.dart';
import 'sell_screen.dart';
import 'orders_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _repo = ShopRepository();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _repo.getProducts();
    if (!mounted) return;
    setState(() {
      _products = p;
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
        title: Text('Магоза',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(AppIcons.history_rounded, color: AppColors.textPrimary),
            tooltip: 'Фармоишҳо',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.neonBlue,
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SellScreen()));
          _load();
        },
        icon: Icon(AppIcons.add_rounded, color: AppColors.textPrimary),
        label: Text('Фуруш',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _products.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.card_giftcard_rounded,
                      color: AppColors.textFaint, size: 56),
                  const SizedBox(height: 12),
                  Text('Ҳанӯз маҳсулот нест',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 15)),
                  Text('Аввалин маҳсулотро эълон кунед 👇',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 10,
                      crossAxisSpacing: 10, childAspectRatio: 0.66,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (_, i) => _card(_products[i]),
                  ),
                ),
    );
  }

  Widget _card(Product p) {
    return GestureDetector(
      onTap: () => _openProduct(p),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 1,
                child: p.image.isEmpty
                    ? Container(color: AppColors.card,
                        child: Icon(AppIcons.image_outlined,
                            color: AppColors.textFaint))
                    : CachedNetworkImage(
                        imageUrl: p.image, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.card),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.card)),
              ),
            ),
            if (p.featured)
              Positioned(top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('⭐ Беҳтарин',
                      style: TextStyle(color: Colors.black, fontSize: 9,
                          fontWeight: FontWeight.w800)),
                )),
            // Тамом шуд (набудани маҳсул).
            if (!p.inStock)
              Positioned.fill(child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.red,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('Тамом шуд',
                        style: TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              )),
          ]),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.productName.isEmpty ? p.caption : p.productName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(p.priceLabel,
                    style: TextStyle(
                        color: AppColors.neonBlue, fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Row(children: [
                  Avatar(imageUrl: p.sellerAvatar, size: 16, name: p.sellerName),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(p.sellerName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 11)),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _openProduct(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductSheet(product: p, repo: _repo),
    );
  }
}

class _ProductSheet extends StatelessWidget {
  final Product product;
  final ShopRepository repo;
  const _ProductSheet({required this.product, required this.repo});

  // Харидан → мустақим ба фурӯшанда. Комиссия ҳам сабт мешавад.
  void _buy(BuildContext context) {
    repo.placeOrder(product.id); // сабти фармоиш + комиссия (fire-and-forget)
    final methods = <String>[];
    if (product.contactRaonson && product.sellerId.isNotEmpty) {
      methods.add('raonson');
    }
    if (product.whatsapp.trim().isNotEmpty) methods.add('whatsapp');
    if (product.phone.trim().isNotEmpty) methods.add('phone');
    if (methods.isEmpty && product.sellerId.isNotEmpty) methods.add('raonson');

    if (methods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Фурӯшанда роҳи алоқа нагузоштааст')));
      return;
    }
    if (methods.length == 1) {
      _openContact(context, methods.first);
    } else {
      _showContactChooser(context, methods);
    }
  }

  void _showContactChooser(BuildContext context, List<String> methods) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('Чӣ тавр бо фурӯшанда алоқа мекунед?',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (methods.contains('raonson'))
            ListTile(
              leading: Icon(AppIcons.chat_bubble_rounded,
                  color: AppColors.neonBlue),
              title: const Text('Чати Raonson'),
              textColor: AppColors.textPrimary,
              onTap: () { Navigator.pop(context); _openContact(context, 'raonson'); },
            ),
          if (methods.contains('whatsapp'))
            ListTile(
              leading: const Icon(AppIcons.public_rounded,
                  color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              textColor: AppColors.textPrimary,
              onTap: () { Navigator.pop(context); _openContact(context, 'whatsapp'); },
            ),
          if (methods.contains('phone'))
            ListTile(
              leading: Icon(AppIcons.call_rounded, color: AppColors.neonBlue),
              title: const Text('Занг задан'),
              textColor: AppColors.textPrimary,
              onTap: () { Navigator.pop(context); _openContact(context, 'phone'); },
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _openContact(BuildContext context, String method) async {
    final msg = 'Салом! Маҳсули «${product.productName}» '
        '(${product.priceLabel})-ро дар Raonson дидам, мехоҳам харам.';
    if (method == 'raonson') {
      final seller = UserModel(
        id: product.sellerId, username: product.sellerName,
        avatar: product.sellerAvatar, verified: product.sellerVerified,
        isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0,
      );
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: seller)));
      return;
    }
    Uri? uri;
    if (method == 'whatsapp') {
      final num = product.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      uri = Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(msg)}');
    } else if (method == 'phone') {
      uri = Uri.parse('tel:${product.phone.trim()}');
    }
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _editProduct(BuildContext context) async {
    final name = TextEditingController(text: product.productName);
    final price = TextEditingController(
        text: product.price == 0 ? '' : product.price.toStringAsFixed(
            product.price % 1 == 0 ? 0 : 2));
    bool inStock = product.inStock;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setD) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Таҳрири маҳсул',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _tf(name, 'Ном'),
          _tf(price, 'Нарх'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: inStock,
            activeColor: const Color(0xFF00C853),
            title: Text('Дар анбор ҳаст',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            onChanged: (v) => setD(() => inStock = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Сабт', style: TextStyle(color: AppColors.neonBlue))),
        ],
      )),
    );
    if (ok == true) {
      await product.updateProduct(product.id,
          name: name.text.trim(),
          price: double.tryParse(price.text.trim()),
          inStock: inStock);
      if (context.mounted) {
        Navigator.pop(context); // варақаро мебандем то магоза нав шавад
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Маҳсул нав шуд ✓'), backgroundColor: Colors.green));
      }
    }
    name.dispose(); price.dispose();
  }

  Future<void> _editTranslations(BuildContext context) async {
    final cur = await product.getTranslations(product.id);
    final ru = TextEditingController(text: cur['ru'] ?? '');
    final en = TextEditingController(text: cur['en'] ?? '');
    final tj = TextEditingController(text: cur['tj'] ?? product.productName);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Тарҷумаи ном',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _tf(tj, 'Тоҷикӣ'),
          _tf(ru, 'Русӣ'),
          _tf(en, 'English'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Сабт', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    if (ok == true) {
      await product.setTranslations(product.id, {
        'tj': tj.text.trim(), 'ru': ru.text.trim(), 'en': en.text.trim(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Тарҷумаҳо сабт шуданд ✓'),
            backgroundColor: Colors.green));
      }
    }
    tj.dispose(); ru.dispose(); en.dispose();
  }

  Widget _tf(TextEditingController c, String hint) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextField(controller: c,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: hint,
          hintStyle: TextStyle(color: AppColors.textFaint))),
  );

  Future<void> _openMap() async {
    if (product.shopLat == 0 && product.shopLng == 0) return;
    final uri = Uri.parse(
        'https://maps.google.com/?q=${product.shopLat},${product.shopLng}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    final hasShop = p.shopLat != 0 || p.shopLng != 0;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          if (p.image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                  imageUrl: p.image, height: 240, width: double.infinity,
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Номи маҳсул бо забони апп (агар тарҷума бошад).
                FutureBuilder<Map<String, String>>(
                  future: product.getTranslations(p.id),
                  builder: (_, snap) {
                    final lang = AppSettingsState.instance.lang;
                    final tr = snap.data?[lang];
                    final name = (tr != null && tr.isNotEmpty)
                        ? tr
                        : (p.productName.isEmpty ? 'Маҳсулот' : p.productName);
                    return Text(name, style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 18,
                        fontWeight: FontWeight.bold));
                  },
                ),
                const SizedBox(height: 6),
                Text(p.priceLabel,
                    style: TextStyle(
                        color: AppColors.neonBlue, fontSize: 20,
                        fontWeight: FontWeight.bold)),
                if (p.caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(p.caption,
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Avatar(imageUrl: p.sellerAvatar, size: 28, name: p.sellerName),
                  const SizedBox(width: 8),
                  Text(p.sellerName,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ]),
                // Соҳиби маҳсул — тугмаи «Беҳтарин кардан» (featured).
                if (p.sellerId == UserSession.userId && p.sellerId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: p.featured
                                ? const Color(0xFFFFD700)
                                : AppColors.divider),
                      ),
                      onPressed: () async {
                        final on = await product.toggleFeature(p.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(on
                                ? 'Маҳсул «беҳтарин» шуд ⭐'
                                : 'Аз «беҳтарин» гирифта шуд'),
                            backgroundColor: Colors.green));
                        }
                      },
                      icon: Icon(AppIcons.star_rounded,
                          color: p.featured
                              ? const Color(0xFFFFD700) : AppColors.textFaint,
                          size: 18),
                      label: Text(
                          p.featured
                              ? 'Аз «беҳтарин» гирифтан'
                              : 'Беҳтарин кардан (боло)',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _editProduct(context),
                      icon: Icon(AppIcons.edit_outlined,
                          color: AppColors.textFaint, size: 16),
                      label: Text('Таҳрир',
                          style: TextStyle(color: AppColors.textPrimary)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _editTranslations(context),
                      icon: Icon(AppIcons.language_rounded,
                          color: AppColors.textFaint, size: 16),
                      label: Text('Тарҷума',
                          style: TextStyle(color: AppColors.textPrimary)),
                    )),
                  ]),
                ],
                if (hasShop) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openMap,
                    child: Row(children: [
                      Icon(AppIcons.location_on, color: Color(0xFFE0245E), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            p.shopAddress.isEmpty
                                ? 'Ба магоза (харита)'
                                : p.shopAddress,
                            style: TextStyle(color: AppColors.neonBlue)),
                      ),
                      Icon(AppIcons.chevron_right_rounded,
                          color: AppColors.textFaint, size: 18),
                    ]),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.inStock
                          ? AppColors.neonBlue : AppColors.divider,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: p.inStock ? () => _buy(context) : null,
                    child: Text(p.inStock ? 'Харидан' : 'Тамом шуд',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
