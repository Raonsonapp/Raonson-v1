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
import '../../models/story_model.dart';
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
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.add, color: Colors.white, size: 28),
          onPressed: () async {
            final r = await Navigator.pushNamed(context, AppRoutes.create);
            if (r == true && context.mounted) {
              context.read<FeedController>().refresh();
              widget.onCreatePost?.call();
            }
          },
        ),
        title: const Text('Raonson', style: TextStyle(
          fontSize: 28, fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold, color: Colors.white,
          fontFamily: 'RaonsonFont', letterSpacing: -0.5,
        )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white, size: 27),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
        ],
      ),
      body: _FeedBody(
        scroll: _scroll,
        isActive: widget.isActive,
        onCreatePost: widget.onCreatePost,
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  final bool isActive;
  final ScrollController scroll;
  final VoidCallback? onCreatePost;
  const _FeedBody({this.isActive = true, required this.scroll, this.onCreatePost});

  // Story кушода мешавад — viewed mark мекунем
  Future<void> _openStory(BuildContext context, StoryModel story) async {
    final storyCtrl = context.read<StoryController>();
    await Navigator.pushNamed(context, '/story-viewer', arguments: story);
    // Баъди баргашт — viewed
    storyCtrl.markViewed(story.id);
  }

  @override
  Widget build(BuildContext context) {
    final feedCtrl  = context.watch<FeedController>();
    final storyCtrl = context.watch<StoryController>();
    final FeedState state = feedCtrl.state;

    Widget storyBar = StoryBar(
      stories:   storyCtrl.stories,
      myStories: storyCtrl.myStories,
      onTap: (s) => _openStory(context, s),
      onAddStory: () async {
        final ok = await Navigator.pushNamed(context, '/create-story');
        if (context.mounted) {
          context.read<StoryController>().loadStories();
          if (ok == true) context.read<FeedController>().refresh();
        }
      },
    );

    if (state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        storyBar,
        const Divider(color: Color(0xFF1A1A1A), height: 1),
        const Expanded(child: Center(child: LoadingIndicator())),
      ]);
    }

    if (!state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        storyBar,
        const Divider(color: Color(0xFF1A1A1A), height: 1),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.photo_camera_outlined, size: 64, color: Colors.white12),
              const SizedBox(height: 16),
              const Text('Ҳоло постҳо нест',
                  style: TextStyle(color: Colors.white38, fontSize: 16)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final r = await Navigator.pushNamed(context, AppRoutes.create);
                  if (r == true && context.mounted) {
                    context.read<FeedController>().refresh();
                    onCreatePost?.call();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Пост гузор'),
              ),
            ]),
          ),
        ),
      ]);
    }

    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: () => feedCtrl.refresh(),
      child: CustomScrollView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: storyBar),
          const SliverToBoxAdapter(
              child: Divider(color: Color(0xFF1A1A1A), height: 1)),
          if (feedCtrl.pendingCount > 0)
            SliverToBoxAdapter(
              child: _NewPostsBanner(
                count: feedCtrl.pendingCount,
                onTap: () {
                  feedCtrl.flushPending();
                  if (scroll.hasClients) {
                    scroll.animateTo(0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut);
                  }
                },
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.posts.length) {
                  return state.hasMore
                      ? const Padding(padding: EdgeInsets.all(16),
                          child: Center(child: LoadingIndicator()))
                      : const SizedBox(height: 40);
                }
                return PostCard(post: state.posts[index], isActive: isActive);
              },
              childCount: state.posts.length + 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPostsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NewPostsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.storyGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(count == 1 ? '1 пости нав' : '$count та пости нав',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
      ),
    );
  }
}
