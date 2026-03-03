import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bottom_nav_bar.dart';
import 'bottom_nav_controller.dart';

import '../../feed/timeline/feed_screen.dart';
import '../../reels/reels_feed/reels_screen.dart';
import '../../chat/inbox/chat_list_screen.dart';
import '../../search/search_screen.dart';
import '../../profile/profile_screen.dart';

class BottomNavScaffold extends StatelessWidget {
  const BottomNavScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BottomNavController(),
      child: const _BottomNavView(),
    );
  }
}

class _BottomNavView extends StatelessWidget {
  const _BottomNavView();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<BottomNavController>();

    return Scaffold(
      body: Stack(
        children: [
          _Tab(active: nav.currentIndex == 0, child: const FeedScreen()),
          _Tab(active: nav.currentIndex == 1, child: ReelsScreen(isActive: nav.currentIndex == 1)),
          _Tab(active: nav.currentIndex == 2, child: const ChatListScreen()),
          _Tab(active: nav.currentIndex == 3, child: const SearchScreen()),
          _Tab(active: nav.currentIndex == 4, child: const ProfileScreen(userId: 'me')),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: nav.currentIndex,
        onTap: nav.setIndex,
        notifCount: 6,
      ),
    );
  }
}

// Offstage wrapper - widget зинда аст аммо RENDER намешавад
// => видео pause мешавад вақте tab иваз шавад
class _Tab extends StatelessWidget {
  final bool active;
  final Widget child;
  const _Tab({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    return Offstage(offstage: !active, child: child);
  }
}
