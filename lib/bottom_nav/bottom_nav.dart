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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 1,
            )
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.play_arrow), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
          ],
        ),
      ),
    );
  }
}
