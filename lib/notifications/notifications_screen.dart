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
    final data = await NotificationApi.fetchForUser('raonson');
    setState(() {
      items = data;
      loading = false;
    });
  }

  String text(AppNotification n) {
    switch (n.type) {
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
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final n = items[i];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: n.from,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' ${text(n)}'),
                      ],
                    ),
                  ),
                  trailing: n.seen
                      ? null
                      : const Icon(Icons.circle,
                          size: 8, color: Colors.blue),
                  onTap: () async {
                    await NotificationApi.markSeen(n.id);
                    load();
                  },
                );
              },
            ),
    );
  }
}
