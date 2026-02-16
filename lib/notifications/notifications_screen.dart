import 'package:flutter/material.dart';

import 'notification_api.dart';
import 'notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  List<AppNotification> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await NotificationApi.fetch('raonson'); // temp user
      setState(() {
        items = data;
        loading = false;
      });
    } catch (_) {
      loading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Notifications'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : items.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final n = items[i];

                    return ListTile(
                      onTap: () async {
                        if (!n.seen) {
                          await NotificationApi.markSeen(n.id);
                          setState(() => n.seen = true);
                        }
                      },
                      leading: Icon(
                        n.type == 'like'
                            ? Icons.favorite
                            : n.type == 'comment'
                                ? Icons.chat_bubble
                                : Icons.person_add,
                        color: n.seen ? Colors.white54 : Colors.red,
                      ),
                      title: Text(
                        '${n.from} ${_text(n.type)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _time(n.createdAt),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  },
                ),
    );
  }

  String _text(String type) {
    switch (type) {
      case 'like':
        return 'liked your post';
      case 'comment':
        return 'commented on your post';
      case 'follow':
        return 'started following you';
      default:
        return '';
    }
  }

  String _time(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
