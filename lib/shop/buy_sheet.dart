// lib/shop/buy_sheet.dart
// Варақаи «Харид» — нарх, промокод (тахфиф) ва алоқа бо фурӯшанда
// (Чати Raonson / WhatsApp / Занг). Фармоиш + комиссияи 5% сабт мешавад.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/tajikshop_brand.dart';
import '../core/api/api_client.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../chat/room/chat_room_screen.dart';
import 'shop_repository.dart';
import '../core/i18n/strings.dart';

void showBuySheet(BuildContext context, PostModel post) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _BuySheet(post: post),
  );
}

class _BuySheet extends StatefulWidget {
  final PostModel post;
  const _BuySheet({required this.post});
  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  final _promoCtrl = TextEditingController();
  int _discountPct = 0;
  String _promoCode = '';
  bool _checking = false;
  String? _promoMsg;

  PostModel get post => widget.post;

  double get _finalPrice =>
      post.price * (1 - _discountPct / 100);

  int get _cashback {
    final v = (_finalPrice * 0.05).floor();
    return v < 1 ? 1 : v;
  }

  List<String> get _methods {
    final m = <String>[];
    if (post.contactRaonson && post.user.id.isNotEmpty) m.add('raonson');
    if (post.shopWhatsapp.trim().isNotEmpty) m.add('whatsapp');
    if (post.shopPhone.trim().isNotEmpty) m.add('phone');
    if (m.isEmpty && post.user.id.isNotEmpty) m.add('raonson');
    return m;
  }

  @override
  void dispose() { _promoCtrl.dispose(); super.dispose(); }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _checking = true; _promoMsg = null; });
    try {
      final r = await ApiClient.instance.post('/shop/promos/validate',
          body: {'code': code, 'sellerId': post.user.id});
      if (!mounted) return; // варақа пӯшида шуд — setState нашавад
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      if (b['valid'] == true) {
        setState(() {
          _discountPct = (b['discountPct'] as num?)?.toInt() ?? 0;
          _promoCode = code;
          _promoMsg = tr('shop.promoApplied', {'n': _discountPct});
        });
      } else {
        setState(() {
          _discountPct = 0; _promoCode = '';
          _promoMsg = (b['message'] ?? 'Код нодуруст').toString();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _promoMsg = 'Санҷиш нашуд');
    }
    if (mounted) setState(() => _checking = false);
  }

  String _priceLabel(double v) =>
      '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} ${post.currency}';

  bool _ordered = false;
  Future<void> _contact(String method) async {
    // Фармоиш танҳо ЯК бор сабт мешавад (server ҳам dedupe мекунад);
    // промокод ба backend меравад, то тахфиф дар фармоиш татбиқ шавад.
    if (!_ordered) {
      _ordered = true;
      ShopRepository().placeOrder(post.id, promoCode: _promoCode);
    }
    final name = post.productName.isNotEmpty
        ? post.productName
        : tr('shop.defaultProduct');
    var msg = tr('shop.buyFull',
        {'name': name, 'price': _priceLabel(_finalPrice)});
    if (_promoCode.isNotEmpty) {
      msg += tr('shop.promoLine', {'code': _promoCode, 'n': _discountPct});
    }
    if (mounted) Navigator.pop(context);
    if (method == 'raonson') {
      final seller = UserModel(
        id: post.user.id, username: post.user.username,
        avatar: post.user.avatar, verified: post.user.verified,
        isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0,
      );
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: seller)));
      return;
    }
    Uri? uri;
    if (method == 'whatsapp') {
      final num = post.shopWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      uri = Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(msg)}');
    } else if (method == 'phone') {
      uri = Uri.parse('tel:${post.shopPhone.trim()}');
    }
    if (uri != null) {
      try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
      catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = _methods;
    return SafeArea(child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        TajikshopBrand.logoCompact(size: 13),
        const SizedBox(height: 8),
        if (post.productName.isNotEmpty)
          Text(post.productName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        // Нарх (бо тахфиф)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_discountPct > 0) ...[
            Text(_priceLabel(post.price),
                style: TextStyle(color: AppColors.textFaint, fontSize: 14,
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(width: 8),
          ],
          Text(_priceLabel(_finalPrice),
              style: TextStyle(color: const Color(0xFF00C853),
                  fontWeight: FontWeight.w800, fontSize: 20)),
        ]),
        const SizedBox(height: 4),
        // Cashback — 5% ҳамчун ситора баргардонида мешавад.
        Text('💰 Cashback: $_cashback ⭐',
            style: TextStyle(color: const Color(0xFFFFD700), fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        // Промокод
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _promoCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: tr('ui.01a191694a'),
                hintStyle: TextStyle(color: AppColors.textFaint),
                prefixIcon: Icon(AppIcons.tag_rounded,
                    color: AppColors.textFaint, size: 18),
                filled: true, fillColor: AppColors.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            )),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _checking ? null : _applyPromo,
              child: _checking
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('ui.198e8aa827'),
                      style: TextStyle(color: AppColors.neonBlue,
                          fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        if (_promoMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_promoMsg!,
                style: TextStyle(
                    color: _discountPct > 0
                        ? const Color(0xFF00C853) : Colors.redAccent,
                    fontSize: 12)),
          ),
        const SizedBox(height: 6),
        Divider(color: AppColors.dividerFaint),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(tr('ui.d74c3a1ba0'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        ),
        if (methods.contains('raonson'))
          ListTile(
            leading: Icon(AppIcons.chat_bubble_rounded, color: AppColors.neonBlue),
            title: Text(tr('ui.006e5dbe34'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => _contact('raonson'),
          ),
        if (methods.contains('whatsapp'))
          ListTile(
            leading: const Icon(AppIcons.public_rounded, color: Color(0xFF25D366)),
            title: Text('WhatsApp',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => _contact('whatsapp'),
          ),
        if (methods.contains('phone'))
          ListTile(
            leading: Icon(AppIcons.call_rounded, color: AppColors.neonBlue),
            title: Text(tr('ui.2db9c265c7'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => _contact('phone'),
          ),
        const SizedBox(height: 16),
      ]),
    ));
  }
}
