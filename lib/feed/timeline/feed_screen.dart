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
import '../comments/comments_screen.dart';
import '../../core/api/api_client.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../widgets/loading_indicator.dart';

class FeedScreen extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onCreatePost;
  const FeedScreen({super.key, this.isActive = true, this.onCreatePost});

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
      child: _FeedShell(isActive: isActive, onCreatePost: onCreatePost),
    );
  }
}

class _FeedShell extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onCreatePost;
  const _FeedShell({this.isActive = true, this.onCreatePost});

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
          onPressed: () async {
            final r = await Navigator.pushNamed(context, AppRoutes.create);
            if (r == true && context.mounted) {
              context.read<FeedController>().refresh();
              widget.onCreatePost?.call();
            }
          },
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
            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
        ],
      ),
      body: _FeedBody(
        scroll: _scroll,
        isActive: widget.isActive,
        onCreatePost: widget.onCreatePost, // ✅ FIX
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  final bool isActive;
  final ScrollController scroll;
  final VoidCallback? onCreatePost; // ✅ FIX

  const _FeedBody({
    this.isActive = true,
    required this.scroll,
    this.onCreatePost, // ✅ FIX
  });

  @override
  Widget build(BuildContext context) {
    final feedCtrl = context.watch<FeedController>();
    final storyCtrl = context.watch<StoryController>();
    final FeedState state = feedCtrl.state;

    if (state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        StoryBar(
          stories: storyCtrl.stories,
          myStories: storyCtrl.myStories,
          onTap: (s) =>
              Navigator.pushNamed(context, '/story-viewer', arguments: s),
          onAddStory: () async {
            final ok = await Navigator.pushNamed(context, '/create-story');
            if (context.mounted) {
              context.read<StoryController>().loadStories();
              if (ok == true) context.read<FeedController>().refresh();
            }
          },
        ),
        const Divider(color: Colors.white10, height: 1),
        const Expanded(
          child: Center(child: LoadingIndicator()),
        ),
      ]);
    }

    if (!state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        StoryBar(
          stories: storyCtrl.stories,
          myStories: storyCtrl.myStories,
          onTap: (s) =>
              Navigator.pushNamed(context, '/story-viewer', arguments: s),
          onAddStory: () async {
            final ok = await Navigator.pushNamed(context, '/create-story');
            if (context.mounted) {
              context.read<StoryController>().loadStories();
              if (ok == true) context.read<FeedController>().refresh();
            }
          },
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: Center(
            child: ElevatedButton(
              onPressed: () async {
                final r =
                    await Navigator.pushNamed(context, AppRoutes.create);
                if (r == true && context.mounted) {
                  context.read<FeedController>().refresh();
                  onCreatePost?.call(); // ✅ FIX
                }
              },
              child: const Text('Пост гузор'),
            ),
          ),
        ),
      ]);
    }

    return ListView.builder(
      controller: scroll,
      itemCount: state.posts.length,
      itemBuilder: (context, index) {
        return PostCard(
          post: state.posts[index],
          isActive: isActive,
        );
      },
    );
  }
}
