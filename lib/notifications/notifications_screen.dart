import 'package:flutter/material.dart';
import 'notifications_repository.dart';
import 'notification_item.dart';
import '../models/notification_model.dart';

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
      setState(() {
        _notifications = data['notifications'] as List<NotificationModel>;
        _unreadCount = data['unreadCount'] as int;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _repo.markAllAsRead();
    setState(() {
      _notifications = _notifications.map((e) => e.copyWith(read: true)).toList();
      _unreadCount = 0;
    });
  }

  Future<void> _onTap(NotificationModel n) async {
    if (!n.isRead) {
      await _repo.markAsRead(n.id);
      setState(() {
        _notifications = _notifications
            .map((e) => e.id == n.id ? e.copyWith(read: true) : e)
            .toList();
        if (_unreadCount > 0) _unreadCount--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Огоҳиномаҳо',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Ҳамаро хондам',
                  style: TextStyle(color: Color(0xFF0095F6), fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Colors.white30, strokeWidth: 2))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: Colors.white,
                  backgroundColor: Colors.black,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => NotificationItem(
                      notification: _notifications[i],
                      onTap: () => _onTap(_notifications[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: const Icon(Icons.notifications_none_outlined,
              color: Colors.white54, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('Огоҳиномае нест',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Вақте кас лайк ё комментария монд,\nинҷо нишон дода мешавад',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
