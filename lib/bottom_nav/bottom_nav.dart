import 'package:flutter/material.dart';
import '../reels/reels_screen.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int index = 1;

  final pages = const [
    Center(child: Text('Home', style: TextStyle(color: Colors.white))),
    ReelsScreen(),
    Center(child: Text('Chat', style: TextStyle(color: Colors.white))),
    Center(child: Text('Search', style: TextStyle(color: Colors.white))),
    Center(child: Text('Profile', style: TextStyle(color: Colors.white))),
  ];

  Widget navIcon(IconData icon, int i) {
    final active = index == i;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔹 GLOW TOP
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 2,
          width: active ? 28 : 0,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            boxShadow: active
                ? [BoxShadow(color: Colors.blueAccent, blurRadius: 12)]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        Icon(icon, color: Colors.white),
        const SizedBox(height: 6),
        // 🔹 GLOW BOTTOM
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 2,
          width: active ? 28 : 0,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            boxShadow: active
                ? [BoxShadow(color: Colors.blueAccent, blurRadius: 12)]
                : [],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: pages[index],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.4),
              blurRadius: 20,
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(onTap: () => setState(() => index = 0), child: navIcon(Icons.home, 0)),
            GestureDetector(onTap: () => setState(() => index = 1), child: navIcon(Icons.play_arrow, 1)),
            GestureDetector(onTap: () => setState(() => index = 2), child: navIcon(Icons.chat_bubble_outline, 2)),
            GestureDetector(onTap: () => setState(() => index = 3), child: navIcon(Icons.search, 3)),
            GestureDetector(onTap: () => setState(() => index = 4), child: navIcon(Icons.person, 4)),
          ],
        ),
      ),
    );
  }
}
