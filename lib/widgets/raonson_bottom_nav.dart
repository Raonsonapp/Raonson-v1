import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/reels/reels_screen.dart';
import '../screens/create/create_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../core/theme/colors.dart';

class RaonsonBottomNav extends StatefulWidget {
  const RaonsonBottomNav({super.key});

  @override
  State<RaonsonBottomNav> createState() => _RaonsonBottomNavState();
}

class _RaonsonBottomNavState extends State<RaonsonBottomNav> {
  int index = 0;

  final pages = const [
    HomeScreen(),
    ReelsScreen(),
    CreateScreen(),
    SearchScreen(),
    ChatListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: RColors.bg,
          boxShadow: [
            BoxShadow(
              color: RColors.neon.withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 2,
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: RColors.neon,
          unselectedItemColor: RColors.white.withOpacity(0.6),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.add_box), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: ''),
          ],
        ),
      ),
    );
  }
}
