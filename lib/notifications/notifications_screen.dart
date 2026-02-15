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
      final data = await NotificationApi.fetch('raonson');
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
                    'No notifications yet',
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
                          load();
                        }
                      },
                      leading: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                      ),
                      title: Text(
                        '${n.from} ${n.type} your post',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        n.createdAt,
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    );
                  },
                ),
    );
  }
}
