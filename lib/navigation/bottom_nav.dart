import 'package:flutter/material.dart';
import '../features/feed/feed_screen.dart';
import '../features/reels/reels_screen.dart';
import '../features/create/create_screen.dart';
import '../features/profile/profile_screen.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _index = 0;

  final screens = const [
    FeedScreen(),
    ReelsScreen(),
    CreateScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: "Reels",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: "Create",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
