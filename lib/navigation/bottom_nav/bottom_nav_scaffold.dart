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
      body: IndexedStack(
        index: nav.currentIndex,
        children: const [
          FeedScreen(),              // HOME
          ReelsScreen(),             // REELS
          ChatListScreen(),          // CHAT
          SearchScreen(),            // SEARCH
          ProfileScreen(userId: 'me')// PROFILE
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: nav.currentIndex,
        onTap: nav.setIndex,
      ),
    );
  }
}
