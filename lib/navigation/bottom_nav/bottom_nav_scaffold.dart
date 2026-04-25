import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bottom_nav_bar.dart';
import 'bottom_nav_controller.dart';
import '../../core/services/user_session.dart';
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

class _BottomNavView extends StatefulWidget {
  const _BottomNavView();

  @override
  State<_BottomNavView> createState() => _BottomNavViewState();
}

class _BottomNavViewState extends State<_BottomNavView> {
  // Keys for refreshing screens
  Key _feedKey    = UniqueKey();
  Key _storiesKey = UniqueKey();
  Key _reelsKey   = UniqueKey();

  void _refreshFeed() {
    setState(() {
      _feedKey    = UniqueKey(); // force FeedScreen rebuild → reload
    });
  }

  void _refreshReels() {
    setState(() => _reelsKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<BottomNavController>();

    return Scaffold(
      body: Stack(
        children: [
          _Tab(
            active: nav.currentIndex == 0,
            child: FeedScreen(
              key: _feedKey,
              isActive: nav.currentIndex == 0,
              onCreatePost: _refreshFeed,
            ),
          ),
          _Tab(
            active: nav.currentIndex == 1,
            child: ReelsScreen(
              key: _reelsKey,
              isActive: nav.currentIndex == 1,
            ),
          ),
          _Tab(active: nav.currentIndex == 2, child: const ChatListScreen()),
          _Tab(active: nav.currentIndex == 3, child: const SearchScreen()),
          _Tab(active: nav.currentIndex == 4, child: const ProfileScreen(userId: 'me')),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<String?>(
        valueListenable: UserSession.avatarNotifier,
        builder: (_, liveAvatar, __) => BottomNavBar(
          currentIndex: nav.currentIndex,
          onTap: nav.setIndex,
          avatarUrl: liveAvatar,
          notifCount: 0,
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final bool   active;
  final Widget child;
  const _Tab({required this.active, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Offstage(offstage: !active, child: child);
  }
}
