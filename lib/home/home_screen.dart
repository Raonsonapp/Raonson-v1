import 'package:flutter/material.dart';
import '../notifications/notifications_screen.dart';
import '../home/post_item.dart';
import '../home/post_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasUnseenNotifications = true;

  final posts = [
    Post(
      id: '1',
      username: 'raonson',
      imageUrl: 'https://picsum.photos/500',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // 🔝 APP BAR
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.add, size: 28),
          onPressed: () {
            // upload modal later
          },
        ),
        centerTitle: true,
        title: const Text(
          'Raonson',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                  setState(() => hasUnseenNotifications = false);
                },
              ),
              if (hasUnseenNotifications)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),

      // 📰 FEED
      body: ListView(
        children: posts.map((p) => PostItem(post: p)).toList(),
      ),
    );
  }
}
