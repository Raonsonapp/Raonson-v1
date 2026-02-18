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
  final NotificationsRepository _repo = NotificationsRepository();

  List<NotificationModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetchNotifications();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) {
      await _repo.markAsRead(n.id);
      setState(() {
        n.read = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await _repo.markAllAsRead();
              setState(() {
                for (final n in _items) {
                  n.read = true;
                }
              });
            },
            child: const Text('Mark all'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _items.isEmpty
              ? const EmptyState(
                  title: 'No notifications',
                  subtitle: 'You are all caught up',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) => NotificationItem(
                      notification: _items[i],
                      onTap: () => _onTap(_items[i]),
                    ),
                  ),
                ),
    );
  }
}
