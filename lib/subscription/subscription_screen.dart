// lib/subscription/subscription_screen.dart
// Саҳифаи обуна. Пардохт ҳоло вуҷуд надорад, бинобар ин экран рост
// мегӯяд, ки обунаҳои пулакӣ дастрас нестанд ва функсияҳо ройгонанд.
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';

class _Group {
  final String emoji, title;
  final List<String> items;
  const _Group(this.emoji, this.title, this.items);
}

const List<_Group> _proGroups = [
  _Group('👤', 'Профил', [
    'Cover Profile (баннер)', 'Аниматсияи махсуси профил',
    'Бештар аз 5 линк дар био', 'Highlights бемаҳдуд',
  ]),
  _Group('📊', 'Аналитика', [
    'Боздидҳои профил', 'Манбаи аудитория', 'Давомнокии тамошои видео',
    'Вақти фаъол будани пайравон', 'Беҳтарин постҳо', 'Афзоиши пайравон',
  ]),
  _Group('☁️', 'Захира', [
    'Сифати аслии акс', 'Видеои 4K', 'Ҳаҷми калонтар барои боргузорӣ',
    'Backup-и абрӣ',
  ]),
  _Group('🎨', 'Дизайн', [
    'Theme-ҳои махсус', 'Иконҳои махсус', 'Аватари аниматсионӣ',
    'Background-и профил',
  ]),
  _Group('🤖', 'AI', [
    'AI барои навиштани Caption', 'AI барои интихоби Hashtag',
    'AI барои беҳтар кардани матн', 'AI барои тарҷума',
    'AI барои ҷамъбасти шарҳҳо',
  ]),
  _Group('🎬', 'Видео', [
    'Трим ва таҳрири иловагӣ', 'Cover-и аниматсионӣ',
    'Subtitle-и автоматикӣ', 'Сифати баландтар',
  ]),
  _Group('💬', 'Чат', [
    'Upload-и файлҳои калон', 'Sticker Pack-и махсус',
    'Folder барои чатҳо', 'Ҷустуҷӯи пешрафта',
  ]),
  _Group('🚀', 'Creator', [
    'Schedule кардани пост', 'Draft-ҳои бемаҳдуд', 'A/B Test барои пост',
    'Insights-и касбӣ',
  ]),
  _Group('🔐', 'Амният', [
    'Login History', 'Дастгоҳҳои фаъол', 'PIN барои Chat',
    'Backup-и танзимот',
  ]),
  _Group('🌟', 'Имтиёзҳо', [
    'Дастрасии барвақт ба функсияҳои нав', 'Priority Support',
    'Нишони Pro дар профил',
  ]),
];

const List<_Group> _bizGroups = [
  _Group('🛍️', 'Shop Premium', [
    'Магозаи расмӣ (Official Store)', 'Баннери калон дар профил',
    'Категорияҳои маҳсулот', 'Каталоги бемаҳдуд',
    'Вариантҳои маҳсулот (ранг, андоза…)', 'SKU ва Barcode',
    'Анбор (Inventory)', 'Пешфармоиш (Pre-order)',
  ]),
  _Group('📈', 'Analytics Pro', [
    'Фурӯш аз рӯи рӯз/ҳафта/моҳ', 'Даромад', 'Фоида', 'Conversion Rate',
    'CTR', 'Impression', 'Reach', 'Customer Return Rate',
    'Average Order Value', 'Top Products', 'Top Cities', 'Top Countries',
    'Top Traffic Sources',
  ]),
  _Group('📢', 'Advertising Center', [
    'Создани реклама', 'Boost Post', 'Boost Reel', 'Boost Product',
    'Campaign Manager', 'Target Audience (синну сол, ҷинс, кишвар, шаҳр, шавқ)',
    'Daily / Lifetime Budget', 'Performance Report',
  ]),
  _Group('🛒', 'Shop Tools', [
    'Купонҳо', 'Промокод', 'Flash Sale', 'Discount', 'Bundle Product',
    'Free Shipping', 'Cashback', 'Limited Offer', 'Gift Card',
  ]),
  _Group('🤖', 'AI Business', [
    'AI Product Description', 'AI SEO', 'AI Translation', 'AI Product Title',
    'AI Background Removal', 'AI Image Enhancement', 'AI Banner Generator',
    'AI Price Suggestion',
  ]),
  _Group('👥', 'Team Management', [
    'Owner', 'Admin', 'Manager', 'Seller', 'Support', 'Moderator',
    'Ҳар кадом ҳуқуқҳои алоҳида',
  ]),
  _Group('📦', 'Order Management', [
    'Pending', 'Confirmed', 'Packed', 'Shipping', 'Delivered',
    'Returned', 'Refunded', 'Cancelled',
  ]),
  _Group('🚚', 'Delivery', [
    'Интегратсия бо хизматрасониҳои хаткашонӣ', 'Tracking Number',
    'Live Tracking', 'Delivery Fee', 'Delivery Zone',
  ]),
  _Group('💳', 'Payments', [
    'Душанбе Сити', 'Alif', 'Корти Миллӣ', 'Visa', 'Mastercard',
    'Apple Pay', 'Google Pay',
  ]),
  _Group('📩', 'Customer Support', [
    'Live Chat', 'Ticket System', 'FAQ', 'Auto Reply', 'Chat Bot',
  ]),
  _Group('⭐', 'Business Verification', [
    'Badge «Official Business»', 'Санҷиши ҳуҷҷатҳои ширкат',
    'Нишони расмӣ барои бренд',
  ]),
  _Group('📅', 'Business Scheduler', [
    'Ба нақша гирифтани постҳо', 'Reels', 'Story', 'Аксияҳо',
  ]),
  _Group('📢', 'Marketing', [
    'Email Campaign', 'Push Notification', 'SMS Campaign',
    'Broadcast Message', 'Loyalty Program',
  ]),
  _Group('🎥', 'Live Shopping', [
    'Live Stream', 'Харидани маҳсулот ҳангоми Live',
    'Сабади харид дар Live', 'Пин кардани маҳсулот дар Live',
  ]),
  _Group('🏪', 'Shop Design', [
    'Theme-и мағоза', 'Баннер', 'Carousel', 'Custom Category',
    'Featured Products',
  ]),
  _Group('📊', 'CRM', [
    'Базаи муштариён', 'Таърихи харид', 'Favorite Products',
    'VIP Customers', 'Customer Notes',
  ]),
  _Group('🌍', 'Multi-language Shop', [
    'Тоҷикӣ', 'Русӣ', 'English', 'Тарҷумаи автоматии маҳсулот',
  ]),
  _Group('💼', 'Invoice', [
    'Invoice PDF', 'Receipt', 'Tax Report', 'Sales Report',
    'Export Excel / CSV',
  ]),
  _Group('🔐', 'Security', [
    '2FA', 'Login History', 'Employee Logs', 'API Key', 'Audit Logs',
  ]),
  _Group('🚀', 'Priority', [
    'Афзалият дар ҷустуҷӯ', 'Афзалият дар Shop',
    'Афзалият дар тавсияҳо', 'Дастгирии техникӣ бо навбати баландтар',
  ]),
];

class SubscriptionScreen extends StatefulWidget {
  final bool business; // кадом планро аввал нишон медиҳем
  const SubscriptionScreen({super.key, this.business = false});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late bool _biz = widget.business;

  List<_Group> get _groups => _biz ? _bizGroups : _proGroups;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: AppColors.bg,
          pinned: true,
          leading: IconButton(
              icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context)),
          title: Text('Обуна',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        SliverToBoxAdapter(child: Column(children: [
          // Рост мегӯем: пардохт ҳоло нест, пас нарх ва тугмаи «Обуна
          // шудан» нишон дода намешаванд — функсияҳо ройгон кушодаанд.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.card,
                borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Icon(AppIcons.star_rounded, color: AppColors.neonBlue, size: 40),
              const SizedBox(height: 10),
              Text('Обунаҳои пулакӣ ҳоло дастрас нестанд',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Ҳамаи функсияҳои зерин ҳозир барои ҳама ройгон '
                  'кушодаанд. Ягон пардохт талаб карда намешавад.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textFaint,
                      fontSize: 13, height: 1.35)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.card,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _toggle('Creator', !_biz, () => setState(() => _biz = false)),
              _toggle('Бизнес', _biz, () => setState(() => _biz = true)),
            ]),
          ),
          const SizedBox(height: 16),
        ])),
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) => _groupCard(_liveGroups[i]),
          childCount: _liveGroups.length,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.neonBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : AppColors.textFaint,
                fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    ));
  }

  /// Танҳо гурӯҳҳое, ки ақаллан ЯК функсияи воқеан коркунанда доранд.
  ///
  /// Пеш ин экран ~120 функсияро бо нишони «скоро» таблиғ мекард —
  /// Official Store, Visa/Mastercard, 2FA-и бизнес, Team Management …
  /// Ҳеҷ кадоме вуҷуд надошт. Корбар гуфт: «намехоҳам ягон қисме дар
  /// экран танҳо барои намоиш бошад». Акнун танҳо он чи КОР МЕКУНАД.
  List<_Group> get _liveGroups => _groups
      .map((g) => _Group(g.emoji, g.title,
          g.items.where(_kAvailable.contains).toList()))
      .where((g) => g.items.isNotEmpty)
      .toList();

  Widget _groupCard(_Group g) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card,
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(g.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(g.title, style: TextStyle(color: AppColors.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ...g.items.map((f) {
          // `_liveGroups` танҳо функсияҳои фаъолро медиҳад.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(AppIcons.check_circle_rounded,
                  color: Color(0xFF00C853), size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(f,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5, height: 1.3))),
          ]),
          );
        }),
      ]),
    );
  }
}

// Функсияҳое ки ҲОЗИР воқеан фаъоланд; дигарон умуман нишон дода намешаванд.
// «PRO»-badge ва Priority Support нестанд — онҳо вуҷуд надоранд.
const Set<String> _kAvailable = {
  // Pro
  'Cover Profile (баннер)', 'Бештар аз 5 линк дар био',
  'Highlights бемаҳдуд',
  'Боздидҳои профил', 'Беҳтарин постҳо', 'Афзоиши пайравон',
  'AI барои навиштани Caption', 'AI барои интихоби Hashtag',
  'AI барои беҳтар кардани матн', 'AI барои тарҷума',
  'AI барои ҷамъбасти шарҳҳо',
  'Schedule кардани пост', 'Insights-и касбӣ',
  'Login History', 'Дастгоҳҳои фаъол', 'PIN барои Chat',
  // Business
  'Анбор (Inventory)', 'Каталоги бемаҳдуд', 'Категорияҳои маҳсулот',
  'Фурӯш аз рӯи рӯз/ҳафта/моҳ', 'Даромад', 'Top Products',
  'Boost Post', 'Boost Product',
  'Купонҳо', 'Промокод', 'Discount', 'Cashback', 'Flash Sale',
  'AI Translation',
  'Pending', 'Confirmed', 'Packed', 'Shipping', 'Delivered',
  'Returned', 'Refunded', 'Cancelled',
  'Live Chat', 'Auto Reply',
  'Ба нақша гирифтани постҳо',
  'Broadcast Message', 'Push Notification',
  'Live Stream',
  'Featured Products',
  'Базаи муштариён', 'Таърихи харид',
  'Тоҷикӣ', 'Русӣ', 'English', 'Тарҷумаи автоматии маҳсулот',
  'Receipt',
};
