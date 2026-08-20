// lib/shop/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/tajikshop_brand.dart';
import '../widgets/avatar.dart';
import '../models/user_model.dart';
import '../core/services/user_session.dart';
import '../app/app_settings.dart';
import 'product_reviews_screen.dart';
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
  String _category = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await _repo.getProducts(category: _category);
    if (!mounted) return;
    setState(() {
      _products = p;
      _loading = false;
    });
  }

  Widget _catChip(String key, String label) {
    final sel = _category == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: GestureDetector(
        onTap: () { if (_category != key) { _category = key; _load(); } },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: TajikshopBrand.logo(size: 24),
        actions: [
          IconButton(
            icon: Icon(AppIcons.history_rounded, color: AppColors.textPrimary),
            tooltip: 'Фармоишҳо',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: SizedBox(height: 46, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _catChip('', 'Ҳама'),
              ...Product.categories.map((c) => _catChip(c, c)),
            ],
          )),
        ),
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
            if (p.onSale)
              Positioned(top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF3040),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text('-${p.salePct}%',
                      style: const TextStyle(color: Colors.white, fontSize: 10,
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
                if (p.onSale)
                  Row(children: [
                    Text(p.salePriceLabel,
                        style: const TextStyle(color: Color(0xFFFF3040),
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(p.priceLabel,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textFaint, fontSize: 11,
                            decoration: TextDecoration.lineThrough))),
                  ])
                else
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
    ).whenComplete(() {
      if (mounted) _load(); // баъди таҳрир/тахфиф грид нав мешавад
    });
  }
}

class _ProductSheet extends StatefulWidget {
  final Product product;
  final ShopRepository repo;
  const _ProductSheet({required this.product, required this.repo});
  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  Product get product => widget.product;
  ShopRepository get repo => widget.repo;

  // Future кэш мешавад — то дар ҳар rebuild дархости нав наравад.
  late final Future<Map<String, String>> _trFuture =
      product.getTranslations(product.id);
  late bool _featured = product.featured;
  bool _ordered = false; // фармоиш танҳо як бор

  // Харидан → аввал интихоби алоқа, фармоиш танҳо баъд аз он сабт мешавад.
  void _buy(BuildContext context) {
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
    // Фармоиш танҳо ҲОЛО (баъди интихоби роҳи алоқа) сабт мешавад —
    // на ҳангоми кушодани варақа; такрор ҳам намешавад.
    if (!_ordered) {
      _ordered = true;
      repo.placeOrder(product.id);
    }
    final effPrice = product.onSale ? product.salePriceLabel : product.priceLabel;
    final msg = 'Салом! Маҳсули «${product.productName}» '
        '($effPrice)-ро дар Raonson дидам, мехоҳам харам.';
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

  Future<void> _editSale(BuildContext context) async {
    final pct = TextEditingController(
        text: product.salePct > 0 ? '${product.salePct}' : '');
    final days = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Flash Sale (тахфиф)',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _tf(pct, 'Тахфиф % (1–90)'),
          _tf(days, 'Чанд рӯз (0 = бе муҳлат)'),
          const SizedBox(height: 4),
          Text('Барои хомӯш кардан — 0 гузоред.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
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
      final saved = await product.setSale(product.id,
          int.tryParse(pct.text.trim()) ?? 0,
          int.tryParse(days.text.trim()) ?? 0);
      if (context.mounted) {
        if (saved) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Тахфиф нав шуд ✓'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Тахфиф сабт нашуд — дубора кӯшиш кунед')));
        }
      }
    }
    pct.dispose(); days.dispose();
  }

  Future<void> _editProduct(BuildContext context) async {
    final name = TextEditingController(text: product.productName);
    final price = TextEditingController(
        text: product.price == 0 ? '' : product.price.toStringAsFixed(
            product.price % 1 == 0 ? 0 : 2));
    bool inStock = product.inStock;
    String cat = product.category;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (_, setD) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Таҳрири маҳсул',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _tf(name, 'Ном'),
          _tf(price, 'Нарх'),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft,
              child: Text('Категория',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
          Wrap(spacing: 6, runSpacing: 6,
            children: Product.categories.map((c) {
              final on = cat == c;
              return GestureDetector(
                onTap: () => setD(() => cat = on ? '' : c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: on ? AppColors.neonBlue : AppColors.surface,
                    borderRadius: BorderRadius.circular(16)),
                  child: Text(c, style: TextStyle(
                      color: on ? Colors.white : AppColors.textSecondary,
                      fontSize: 12)),
                ),
              );
            }).toList()),
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
      final saved = await product.updateProduct(product.id,
          category: cat,
          name: name.text.trim(),
          price: double.tryParse(price.text.trim()),
          inStock: inStock);
      if (context.mounted) {
        if (saved) {
          Navigator.pop(context); // варақа пӯшида → грид нав мешавад
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Маҳсул нав шуд ✓'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Сабт нашуд — дубора кӯшиш кунед')));
        }
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
                  future: _trFuture,
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
                if (p.onSale)
                  Row(children: [
                    Text(p.salePriceLabel,
                        style: const TextStyle(color: Color(0xFFFF3040),
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(p.priceLabel,
                        style: TextStyle(color: AppColors.textFaint, fontSize: 14,
                            decoration: TextDecoration.lineThrough)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFF3040),
                          borderRadius: BorderRadius.circular(5)),
                      child: Text('-${p.salePct}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ])
                else
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
                            color: _featured
                                ? const Color(0xFFFFD700)
                                : AppColors.divider),
                      ),
                      onPressed: () async {
                        final on = await product.toggleFeature(p.id);
                        if (!mounted) return;
                        if (on == null) {
                          // Хато — статуси кӯҳна мемонад, дурӯғи «муваффақ» нест.
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Иваз нашуд — дубора кӯшиш кунед')));
                          return;
                        }
                        setState(() => _featured = on);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(on
                              ? 'Маҳсул «беҳтарин» шуд ⭐'
                              : 'Аз «беҳтарин» гирифта шуд'),
                          backgroundColor: Colors.green));
                      },
                      icon: Icon(AppIcons.star_rounded,
                          color: _featured
                              ? const Color(0xFFFFD700) : AppColors.textFaint,
                          size: 18),
                      label: Text(
                          _featured
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
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _editSale(context),
                      icon: const Icon(AppIcons.tag_rounded,
                          color: Color(0xFFFF3040), size: 16),
                      label: Text(p.onSale
                              ? 'Тахфиф: -${p.salePct}% (тағйир)'
                              : 'Flash Sale (тахфиф)',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
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
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProductReviewsScreen(
                          postId: p.id, productName: p.productName))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(AppIcons.star_rounded,
                          color: const Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 8),
                      Text('Баҳоҳо ва шарҳҳо',
                          style: TextStyle(color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Icon(AppIcons.chevron_right_rounded,
                          color: AppColors.textFaint, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
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
