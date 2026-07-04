// lib/shop/buy_sheet.dart
// Варақаи «Харид» барои пости магоза — дар феед, риелс ва search истифода мешавад.
// Фармоишро сабт мекунад (комиссияи 5%) ва ба фурӯшанда мерасонад:
// Чати Raonson / WhatsApp / Занг.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../chat/room/chat_room_screen.dart';
import 'shop_repository.dart';

void showBuySheet(BuildContext context, PostModel post) {
  final methods = <String>[];
  if (post.contactRaonson && post.user.id.isNotEmpty) methods.add('raonson');
  if (post.shopWhatsapp.trim().isNotEmpty) methods.add('whatsapp');
  if (post.shopPhone.trim().isNotEmpty) methods.add('phone');
  if (methods.isEmpty && post.user.id.isNotEmpty) methods.add('raonson');

  // Фармоишро сабт мекунем (fire-and-forget) — комиссия дар backend.
  ShopRepository().placeOrder(post.id);

  if (methods.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Фурӯшанда роҳи алоқа нагузоштааст')));
    return;
  }
  if (methods.length == 1) {
    _openContact(context, post, methods.first);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        if (post.productName.isNotEmpty)
          Text(post.productName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 15)),
        Text('${post.priceLabel} · алоқа бо фурӯшанда',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        const SizedBox(height: 8),
        if (methods.contains('raonson'))
          ListTile(
            leading: Icon(AppIcons.chat_bubble_rounded, color: AppColors.neonBlue),
            title: Text('Чати Raonson',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _openContact(context, post, 'raonson'); },
          ),
        if (methods.contains('whatsapp'))
          ListTile(
            leading: const Icon(AppIcons.public_rounded, color: Color(0xFF25D366)),
            title: Text('WhatsApp',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _openContact(context, post, 'whatsapp'); },
          ),
        if (methods.contains('phone'))
          ListTile(
            leading: Icon(AppIcons.call_rounded, color: AppColors.neonBlue),
            title: Text('Занг задан',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _openContact(context, post, 'phone'); },
          ),
        const SizedBox(height: 16),
      ]),
    ),
  );
}

Future<void> _openContact(
    BuildContext context, PostModel post, String method) async {
  final name = post.productName.isNotEmpty ? post.productName : 'маҳсул';
  final msg = 'Салом! «$name» (${post.priceLabel})-ро дар Raonson дидам, '
      'мехоҳам харам.';
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
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
