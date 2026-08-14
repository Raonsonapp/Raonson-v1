// lib/subscription/subscription_screen.dart
// Raonson Pro (29.90 сом) ва Raonson Business (99.90 сом) — саҳифаи обуна.
// Ҳамаи хусусиятҳо аз рӯи категория нишон дода мешаванд.
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
    'Badge «PRO»', 'Cover Profile (баннер)', 'Аниматсияи махсуси профил',
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
  String get _price => _biz ? '99.90' : '29.90';
  String get _name  => _biz ? 'Raonson Business' : 'Raonson Pro';
  List<Color> get _grad => _biz
      ? const [Color(0xFFF7971E), Color(0xFFFFD200)]
      : const [Color(0xFF7F00FF), Color(0xFFE100FF)];

  void _subscribe() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Text('Фаъол кардани $_name',
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          Text('$_price сомонӣ / моҳ',
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(AppIcons.rocket_launch_outlined,
                size: 48, color: AppColors.neonBlue),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
                'Пардохт тавассути Google Play ба зудӣ фаъол мешавад. '
                'Мо дар ҳоли ҳамкорӣ бо Google Play Billing ҳастем.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Фаҳмидам',
                style: TextStyle(color: AppColors.neonBlue, fontSize: 15)),
          ),
          const SizedBox(height: 12),
        ])),
    );
  }

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
          title: Text(_name,
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        SliverToBoxAdapter(child: Column(children: [
          // Hero
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _grad,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Icon(_biz ? AppIcons.business_center_rounded : AppIcons.star_rounded,
                  color: Colors.white, size: 44),
              const SizedBox(height: 10),
              Text(_name,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_biz
                  ? 'Барои бизнес ва брендҳо — фурӯш, реклама, CRM'
                  : 'Барои creator-ҳо — аналитика, AI, дизайн, амният',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              Text('$_price сомонӣ',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 28, fontWeight: FontWeight.w900)),
              const Text('дар як моҳ',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          // Plan toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.card,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _toggle('Pro', !_biz, () => setState(() => _biz = false)),
              _toggle('Business', _biz, () => setState(() => _biz = true)),
            ]),
          ),
          const SizedBox(height: 16),
        ])),
        // Feature groups
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) => _groupCard(_groups[i]),
          childCount: _groups.length,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ]),
      bottomSheet: SafeArea(
        child: Container(
          color: AppColors.bg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _grad.last,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _subscribe,
              child: Text('Обуна шудан — $_price сом/моҳ',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? _grad.last : Colors.transparent,
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
          final on = _kAvailable.contains(f);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(on ? AppIcons.check_circle_rounded : AppIcons.schedule_rounded,
                  color: on ? const Color(0xFF00C853) : AppColors.textFaint,
                  size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(f,
                  style: TextStyle(
                      color: on ? AppColors.textSecondary : AppColors.textFaint,
                      fontSize: 13.5, height: 1.3))),
              if (!on)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(5)),
                  child: Text('ба зудӣ',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 9)),
                ),
            ]),
          );
        }),
      ]),
    );
  }
}

// Функсияҳое ки ҲОЗИР воқеан фаъоланд (сабз ✓); дигарон «ба зудӣ».
const Set<String> _kAvailable = {
  // Pro
  'Badge «PRO»', 'Cover Profile (баннер)', 'Бештар аз 5 линк дар био',
  'Highlights бемаҳдуд',
  'Боздидҳои профил', 'Беҳтарин постҳо', 'Афзоиши пайравон',
  'AI барои навиштани Caption', 'AI барои интихоби Hashtag',
  'AI барои беҳтар кардани матн', 'AI барои тарҷума',
  'AI барои ҷамъбасти шарҳҳо',
  'Schedule кардани пост', 'Insights-и касбӣ',
  'Login History', 'Дастгоҳҳои фаъол', 'PIN барои Chat',
  'Нишони Pro дар профил', 'Priority Support',
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
  'Broadcast Message', 'Push Notification', 'Loyalty Program',
  'Live Stream',
  'Featured Products',
  'Базаи муштариён', 'Таърихи харид',
  'Тоҷикӣ', 'Русӣ', 'English', 'Тарҷумаи автоматии маҳсулот',
  'Receipt',
};
