import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'notifications_repository.dart';
import 'notification_item.dart';
import '../models/notification_model.dart';
import '../app/app_theme.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import '../core/services/notification_badge_controller.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = (data['notifications'] as List?)
            ?.cast<NotificationModel>() ?? const <NotificationModel>[];
        _unreadCount = (data['unreadCount'] as int?) ?? 0;
        _loading = false;
      });
      // Бейҷи глобалиро бо шумораи воқеӣ синхрон мекунем.
      NotificationBadgeController.instance.setCount(_unreadCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
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
      await _repo.markAsRead(n.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((e) => e.id == n.id ? e.copyWith(read: true) : e)
            .toList();
        if (_unreadCount > 0) _unreadCount--;
      });
      NotificationBadgeController.instance.decrement();
    }
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
      body: _loading
          ? const _NotifSkeleton()
          : _notifications.isEmpty
              ? _buildEmpty()
              : _buildGroupedList(),
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
    section(tr('common.earlier'), week);
    section(tr('common.earlier'), earlier);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.textPrimary,
      backgroundColor: AppColors.bg,
      child: ListView(padding: const EdgeInsets.only(top: 4), children: children),
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
        Text('Вақте кас лайк ё комментария монд,\nинҷо нишон дода мешавад',
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
