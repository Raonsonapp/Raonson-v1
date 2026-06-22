import 'package:flutter/material.dart';
import '../core/ui/app_icons.dart';

class AppScaffold extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTabChanged,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(AppIcons.home_outlined),
            activeIcon: Icon(AppIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.movie_outlined),
            activeIcon: Icon(AppIcons.movie),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.chat_bubble_outline),
            activeIcon: Icon(AppIcons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.search),
            activeIcon: Icon(AppIcons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.person_outline),
            activeIcon: Icon(AppIcons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
