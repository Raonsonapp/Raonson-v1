import 'package:flutter/material.dart';
import 'notification_api.dart';
import 'notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await NotificationApi.fetch();
    items = data
        .map<AppNotification>((e) => AppNotification.fromJson(e))
        .toList();
    setState(() => loading = false);
    await NotificationApi.markSeen();
  }

  String buildText(AppNotification n) {
    if (n.type == 'like') return '${n.from} liked your post';
    if (n.type == 'follow') return '${n.from} started following you';
    if (n.type == 'comment') return '${n.from} commented on your post';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: items.map((n) {
                return ListTile(
                  title: Text(
                    buildText(n),
                    style: TextStyle(
                      color: n.seen ? Colors.white54 : Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
