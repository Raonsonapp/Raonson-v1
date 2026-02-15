import 'package:flutter/material.dart';

// AUTH
import 'auth/auth_gate.dart';

// SCREENS
import 'home/home_screen.dart';
import 'reels/reels_screen.dart';

/// 🔹 ROOT APP (MaterialApp ONLY HERE)
class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const AuthGate(),
    );
  }
}

/// 🔹 MAIN NAVIGATION (AFTER LOGIN)
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int index = 0; // ⬅️ Home аввал

  final List<Widget> pages = const [
    HomeScreen(),   // 🏠 HOME (реалӣ)
    ReelsScreen(),  // 🎬 REELS
    Center(
      child: Text(
        'Search',
        style: TextStyle(color: Colors.white),
      ),
    ),
    Center(
      child: Text(
        'Profile',
        style: TextStyle(color: Colors.white),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '',
          ),
        ],
      ),
    );
  }
}
