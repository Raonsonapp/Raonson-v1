import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'feed_controller.dart';
import 'feed_state.dart';
import '../post/post_card.dart';

import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

import '../../navigation/bottom_nav/bottom_nav_bar.dart';
import '../../navigation/bottom_nav/bottom_nav_controller.dart';
import '../../navigation/drawer/app_drawer.dart';

import '../../reels/reels_feed/reels_screen.dart';
import '../../chat/inbox/chat_list_screen.dart';
import '../../profile/profile_screen.dart';

import '../../app/app_routes.dart';
import '../../core/api/api_client.dart';
import '../feed_repository.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FeedController(
            FeedRepository(ApiClient.instance),
          )..loadInitialFeed(),
        ),
        ChangeNotifierProvider(
          create: (_) => BottomNavController(),
        ),
      ],
      child: const _FeedShell(),
    );
  }
}

class _FeedShell extends StatefulWidget {
  const _FeedShell();

  @override
  State<_FeedShell> createState() => _FeedShellState();
}

class _FeedShellState extends State<_FeedShell> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final controller = context.read<FeedController>();
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<BottomNavController>();

    return Scaffold(
      drawer: AppDrawer(
        onProfile: () {
          Navigator.pop(context);
          nav.setIndex(4);
        },
        onSaved: () {},
        onSettings: () {},
        onLogout: () {},
      ),
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: nav.currentIndex,
        children: [
          _buildFeed(context),
          const ReelsScreen(),
          const ChatListScreen(),
          const Center(child: Text('Search')),
          const ProfileScreen(userId: 'me'),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: nav.currentIndex,
        onTap: nav.setIndex,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      title: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Text(
          'Raonson',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.create);
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.notifications);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFeed(BuildContext context) {
    return Consumer<FeedController>(
      builder: (_, controller, __) {
        final FeedState state = controller.state;

        if (state.isLoading && state.posts.isEmpty) {
          return const Center(child: LoadingIndicator());
        }

        if (state.hasError) {
          return Center(
            child: Text(state.errorMessage ?? 'Unexpected error'),
          );
        }

        if (state.posts.isEmpty) {
          return const EmptyState(
            icon: Icons.image_not_supported,
            title: 'No posts yet',
            subtitle: 'Follow users to see posts in your feed',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: state.posts.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < state.posts.length) {
                return PostCard(post: state.posts[index]);
              }

              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: LoadingIndicator()),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
