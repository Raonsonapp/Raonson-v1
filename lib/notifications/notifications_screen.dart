import 'package:flutter/material.dart';
import 'notifications_repository.dart';
import 'notification_item.dart';
import '../models/notification_model.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsRepository _repository = NotificationsRepository();
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repository.fetchNotifications();
      setState(() {
        _notifications = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _onNotificationTap(NotificationModel n) async {
    if (!n.isRead) {
      await _repository.markAsRead(n.id);
      setState(() {
        n.isRead = true;
      });
    }

    // navigation handled by route guards / app routes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          TextButton(
            onPressed: () async {
              await _repository.markAllAsRead();
              setState(() {
                for (final n in _notifications) {
                  n.isRead = true;
                }
              });
            },
            child: const Text("Mark all"),
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _notifications.isEmpty
              ? const EmptyState(
                  title: "No notifications",
                  subtitle: "You’re all caught up 🎉",
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      return NotificationItem(
                        notification: n,
                        onTap: () => _onNotificationTap(n),
                      );
                    },
                  ),
                ),
    );
  }
}
