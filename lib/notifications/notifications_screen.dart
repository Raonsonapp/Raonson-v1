import '../widgets/stale_data_banner.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;

import '../core/firebase_init.dart';
import '../core/notifications/notification_permission_sheet.dart';
import 'package:shimmer/shimmer.dart';
import 'notifications_repository.dart';
import 'notification_item.dart';
import '../models/notification_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../feed/post/post_detail_screen.dart';
import '../reels/single_reel_screen.dart';
import '../shop/orders_screen.dart';
import '../effects/effects_screen.dart';
import '../discover/discover_screen.dart';
import '../core/api/api_client.dart';
import '../app/app_theme.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import '../core/services/notification_badge_controller.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'notification_badge.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationsRepository();
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _hasError = false;
  // Саҳифабандӣ. Пеш танҳо 30 огоҳиномаи охирин буд — кӯҳнатаринҳо
  // ҳеҷ гоҳ нишон дода намешуданд.
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    NotificationBadgeController.instance.reset();
    NotificationService.markRead();
    _load();
    // Иҷозат маҳз ин ҷо пурсида мешавад: корбар аллакай ба
    // огоҳиномаҳо таваҷҷуҳ дорад. Дар кадри аввали барнома пурсидан
    // одатан ба «Рад» меанҷомад ва баъд такрор пурсидан мумкин нест.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskPermission());
  }

  Future<void> _maybeAskPermission() async {
    final status = await FirebaseInit.permissionStatus();
    // Танҳо вақте мепурсем, ки корбар ҳанӯз қарор накардааст.
    if (status != AuthorizationStatus.notDetermined) return;
    if (!mounted) return;
    await NotificationPermissionSheet.ask(context);
  }

  /// Шабака нашуд — огоҳиҳои охирин аз кэш нишон дода мешаванд.
  bool _stale = false;

  /// Аввал кэш (фавран, бе интернет), баъд шабака.
  Future<void> _load() async {
    setState(() {
      _loading = _notifications.isEmpty;
      _hasError = false;
    });
    if (_notifications.isEmpty) {
      final cached = await _repo.cachedNotifications();
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty && _notifications.isEmpty) {
        setState(() { _notifications = cached; _loading = false; });
      }
    }
    try {
      final data = await _repo.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = (data['notifications'] as List?)
            ?.cast<NotificationModel>().toList() ?? <NotificationModel>[];
        _unreadCount = (data['unreadCount'] as int?) ?? 0;
        _hasMore = _notifications.length >= NotificationsRepository.pageSize;
        _loading = false;
        _stale = false;
      });
      _repo.markAllAsRead().catchError((_) {});
      NotificationBadgeController.instance.reset();
      NotificationService.markRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
        _stale = _notifications.isNotEmpty;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    _loadingMore = true;
    try {
      final data = await _repo.fetchNotifications(
          page: _notifications.length ~/ NotificationsRepository.pageSize + 1);
      if (!mounted) return;
      final page = (data['notifications'] as List?)
              ?.cast<NotificationModel>() ?? const <NotificationModel>[];
      final seen = _notifications.map((n) => n.id).toSet();
      final fresh = page.where((n) => seen.add(n.id)).toList();
      setState(() {
        _notifications = [..._notifications, ...fresh];
        _hasMore = page.length >= NotificationsRepository.pageSize &&
            fresh.isNotEmpty;
      });
    } catch (_) {
      // Ҳангоми ғелондани навбатӣ боз кӯшиш мешавад.
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _markAllRead() async {
    try { await _repo.markAllAsRead(); } catch (_) { return; }
    if (!mounted) return;
    setState(() {
      _notifications = _notifications.map((e) => e.copyWith(read: true)).toList();
      _unreadCount = 0;
    });
    NotificationBadgeController.instance.reset();
  }

  Future<void> _onTap(NotificationModel n) async {
    AnalyticsService.instance.logEvent(AnalyticsEvents.notificationOpen,
        params: {'type': n.type});
    if (!n.isRead) {
      // Хатои шабака набояд гузаришро манъ кунад — пеш пахш бе интернет
      // ҳеҷ кор намекард (истисно ҳамаро қатъ мекард).
      try { await _repo.markAsRead(n.id); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((e) => e.id == n.id ? e.copyWith(read: true) : e)
            .toList();
        if (_unreadCount > 0) _unreadCount--;
      });
      NotificationBadgeController.instance.decrement();
    }
    if (!mounted) return;
    await _navigate(n);
  }

  // ── Deep-link: аз рӯи навъи огоҳинома ба саҳифаи дахлдор ─────────
  Future<void> _navigate(NotificationModel n) async {
    switch (n.type) {
      case 'like':
      case 'comment':
      case 'reply':
      case 'mention':
        await _openPost(n.targetId);
        break;
      case 'collab_accepted':
        await _openPost(n.targetId);
        break;
      case 'reel_like':
      case 'reel_comment':
      case 'reel_mention':
        await _openReel(n.targetId);
        break;
      case 'collab_invite':
        // Даъват ба ҷои ҚАБУЛ мебарад, на ба худи пост (ҳоло ҳамкор нест).
        Navigator.pushNamed(context, '/collab-invites');
        break;
      case 'trending_topic':
        // Мавзӯъҳо дар «Кашфи имрӯз» ҳастанд — ҳамон ҷо, ки линки /topic.
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DiscoverScreen()));
        break;
      case 'follow':
      case 'follow_request':
      case 'follow_accepted':
      case 'story_addyours':
      case 'gift':
      case 'recommended_creator':
      case 'referral_joined':
      case 'story_like':
      case 'story_reply':
      case 'story_poll':
      case 'story_answer':
      case 'story_quiz':
      case 'story_mention':
      case 'note_reaction':
        _openProfile(n.fromUser?.id);
        break;
      case 'order':
        try {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()));
        } catch (_) {}
        break;
      case 'effect_sale':
        try {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const EffectsScreen()));
        } catch (_) {}
        break;
      default:
        // Навъи нав/ношинос: ҳадди ақал профили иҷрокунанда — беҳтар аз
        // пахше, ки ҳеҷ кор намекунад.
        _openProfile(n.fromUser?.id);
        break;
    }
  }

  Future<void> _openPost(String? postId) async {
    if (postId == null || postId.isEmpty) return;
    try {
      final res = await ApiClient.instance.get('/posts/$postId');
      if (res.statusCode >= 400) return _unavailable();
      final post =
          PostModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => PostDetailScreen(
              posts: [post], initialIndex: 0, title: tr('post.title'))));
    } catch (_) {}
  }

  Future<void> _openReel(String? reelId) async {
    if (reelId == null || reelId.isEmpty) return;
    try {
      // GET /reels/:id мавҷуд аст — пеш танҳо 24 рилси ХУДРО меҷустем,
      // бинобар ин рилси каси дигар (зикр, шарҳ) ҳеҷ гоҳ кушода намешуд.
      final res = await ApiClient.instance.get('/reels/$reelId');
      if (res.statusCode >= 400) return _unavailable();
      final reel =
          ReelModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SingleReelScreen(reel: reel)));
    } catch (_) {}
  }

  /// Пост/Reels нест шуд ё пӯшида аст. Пеш пахш ҳеҷ натиҷа надошт ва
  /// корбар гумон мекард, ки барнома ҳалқ шуд.
  void _unavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('link.unavailable')),
        duration: const Duration(seconds: 2)));
  }

  void _openProfile(String? userId) {
    if (userId == null || userId.isEmpty) return;
    try {
      Navigator.pushNamed(context, '/profile', arguments: userId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false, // сарлавҳа ба чап — мисли Instagram
        title: Text(tr('common.notifications'),
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(tr('common.markAllRead'),
                  style: const TextStyle(color: Color(0xFF0095F6), fontSize: 13)),
            ),
        ],
      ),
      body: Column(children: [
        StaleDataBanner(visible: _stale && !_loading, onRetry: _load),
        Expanded(
          child: _loading
              ? const _NotifSkeleton()
              : _hasError && _notifications.isEmpty
                  ? _pullable(_buildError())
                  : _notifications.isEmpty
                      ? _pullable(_buildEmpty())
                      : _buildGroupedList(),
        ),
      ]),
    );
  }

  // ── Гурӯҳбандӣ аз рӯи вақт — мисли Instagram ──────────────────
  Widget _buildGroupedList() {
    final now = DateTime.now();
    final yDay = now.subtract(const Duration(days: 1));
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final today = <NotificationModel>[];
    final yesterday = <NotificationModel>[];
    final week = <NotificationModel>[];
    final earlier = <NotificationModel>[];
    for (final n in _notifications) {
      final d = n.createdAt.toLocal();
      if (sameDay(d, now)) {
        today.add(n);
      } else if (sameDay(d, yDay)) {
        yesterday.add(n);
      } else if (now.difference(d).inDays < 7) {
        week.add(n);
      } else {
        earlier.add(n);
      }
    }

    final children = <Widget>[];
    void section(String title, List<NotificationModel> items) {
      if (items.isEmpty) return;
      children.add(_sectionHeader(title));
      children.addAll(items.map((n) =>
          NotificationItem(notification: n, onTap: () => _onTap(n))));
    }

    section(tr('common.today'), today);
    section(tr('common.yesterday'), yesterday);
    // Пеш ин ҳам «Қаблтар» буд — ду сарлавҳаи якхела паси ҳам.
    section(tr('common.thisWeek'), week);
    section(tr('common.earlier'), earlier);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.textPrimary,
      backgroundColor: AppColors.bg,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) _loadMore();
          return false;
        },
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4), children: children),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      );

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(AppIcons.wifi_off_rounded,
            color: AppColors.textFaint, size: 48),
        const SizedBox(height: 16),
        Text(tr('common.noConnection'),
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(tr('common.checkInternet'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(AppIcons.refresh_rounded, size: 18),
          label: Text(tr('common.retryLong')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0095F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 10)),
        ),
      ]),
    );
  }

  /// Ҳолати холӣ/хато низ бо кашидан ба поён нав мешавад.
  Widget _pullable(Widget child) => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.textPrimary,
        backgroundColor: AppColors.bg,
        child: LayoutBuilder(builder: (_, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: child),
        )),
      );

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textFaint, width: 2),
          ),
          child: Icon(AppIcons.notifications_none_outlined,
              color: AppColors.textTertiary, size: 40),
        ),
        const SizedBox(height: 16),
        Text(tr('common.noNotifications'),
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Text(tr('notif.emptyHint'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Shimmer skeleton — avatar + 2 lines ──────────────────────────────
class _NotifSkeleton extends StatelessWidget {
  const _NotifSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withOpacity(0.4),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 9,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: double.infinity, height: 12,
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(width: 140, height: 12,
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
