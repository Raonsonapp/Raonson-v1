import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
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
          create: (ctx) {
            final ctrl = FeedController(FeedRepository());
            ctrl.onUnauthorized = () => ctx.read<AppState>().logout();
            ctrl.loadInitialFeed();
            return ctrl;
          },
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
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 26),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.create),
        ),
        title: const Text('Raonson',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                color: Colors.white, fontFamily: 'RaonsonFont')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
          ),
        ],
      ),
      body: _FeedBody(scroll: _scroll),
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

    // Loading
    if (state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        StoryBar(stories: storyCtrl.stories, onTap: (_) {}, onAddStory: () => Navigator.pushNamed(context, '/create-story')),
        const Divider(color: Colors.white10, height: 1),
        const Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LoadingIndicator(),
              SizedBox(height: 16),
              Text('Server бедор мешавад...',
                  style: TextStyle(color: AppColors.grey, fontSize: 13)),
              SizedBox(height: 4),
              Text('30-60 сония интизор шавед',
                  style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ]);
    }

    // Error — shows REAL error message for debugging
    if (state.hasError && state.posts.isEmpty) {
      return Column(children: [
        StoryBar(stories: storyCtrl.stories, onTap: (_) {}, onAddStory: () => Navigator.pushNamed(context, '/create-story')),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off, color: AppColors.grey, size: 52),
                const SizedBox(height: 12),
                const Text('Пайваст нашуд',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // REAL ERROR for debugging
                if (state.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: feedCtrl.loadInitialFeed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Боз кушиш кун'),
                ),
              ]),
            ),
          ),
        ),
      ]);
    }

    // Empty
    if (!state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        StoryBar(stories: storyCtrl.stories, onTap: (_) {}, onAddStory: () => Navigator.pushNamed(context, '/create-story')),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.photo_library_outlined,
                  color: AppColors.grey, size: 64),
              const SizedBox(height: 16),
              const Text('Постхо нест',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.create),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Пост гузор'),
              ),
            ]),
          ),
        ),
      ]);
    }

    // Posts list
    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: feedCtrl.refresh,
      child: ListView.builder(
        controller: scroll,
        itemCount: 1 + state.posts.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(children: [
              StoryBar(stories: storyCtrl.stories, onTap: (_) {}, onAddStory: () => Navigator.pushNamed(context, '/create-story')),
              const Divider(color: Colors.white10, height: 1),
            ]);
          }
          final i = index - 1;
          if (i < state.posts.length) return PostCard(post: state.posts[i]);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: LoadingIndicator()),
          );
        },
      ),
    );
  }
}
