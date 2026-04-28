import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../app/app_theme.dart';

// ── Notification badge ValueNotifier ────────────────────────────────
class NotificationService {
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static Timer? _timer;

  static void startPolling() {
    _timer?.cancel();
    _fetchCount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchCount());
  }

  static void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _fetchCount() async {
    try {
      final res = await ApiClient.instance
          .get('/notifications/unread-count')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final count = (body['count'] ?? body['unreadCount'] ?? 0) as int;
        unreadCount.value = count;
      }
    } catch (_) {}
  }

  static void markRead() => unreadCount.value = 0;
}

// ── Badge виджет ─────────────────────────────────────────────────────
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final Color badgeColor;

  const NotificationBadge({
    super.key,
    required this.child,
    this.badgeColor = AppColors.red,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unreadCount,
      builder: (_, count, __) {
        if (count <= 0) return child;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              top: -4,
              right: -4,
              child: AnimatedScale(
                scale: count > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.elasticOut,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
