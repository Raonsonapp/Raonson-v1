import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../feed_repository.dart';
import 'feed_controller.dart';
import 'feed_state.dart';
import '../post/post_card.dart';
import '../../stories/story_bar.dart';
import '../../stories/story_controller.dart';
import '../../stories/story_repository.dart';
import '../../core/api/api_client.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../widgets/loading_indicator.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FeedController(FeedRepository())..loadInitialFeed(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              StoryController(StoryRepository(ApiClient.instance))
                ..loadStories(),
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
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      context.read<FeedController>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      body: _FeedBody(scroll: _scroll),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 26),
        onPressed: () => Navigator.pushNamed(context, AppRoutes.create),
      ),
      title: const Text(
        'Raonson',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'RaonsonFont',
        ),
      ),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            ],
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
        ),
      ],
    );
  }
}

class _FeedBody extends StatelessWidget {
  final ScrollController scroll;
  const _FeedBody({required this.scroll});

  @override
  Widget build(BuildContext context) {
    final feedCtrl = context.watch<FeedController>();
    final storyCtrl = context.watch<StoryController>();
    final FeedState state = feedCtrl.state;

    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: feedCtrl.refresh,
      child: ListView.builder(
        controller: scroll,
        itemCount: 1 +
            state.posts.length +
            (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Item 0 = Story bar
          if (index == 0) {
            return Column(
              children: [
                // Stories
                StoryBar(
                  stories: storyCtrl.stories,
                  onTap: (_) {},
                  onAddStory: () {},
                ),
                const Divider(color: Colors.white10, height: 1),
              ],
            );
          }

          final postIndex = index - 1;

          if (postIndex < state.posts.length) {
            return PostCard(post: state.posts[postIndex]);
          }

          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: LoadingIndicator()),
          );
        },
      ),
    );
  }
}
