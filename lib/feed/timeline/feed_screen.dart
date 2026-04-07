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
        onCreatePost: widget.onCreatePost,
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  final bool isActive;
  final ScrollController scroll;
  final VoidCallback? onCreatePost;

  const _FeedBody({
    this.isActive = true,
    required this.scroll,
    this.onCreatePost,
  });

  @override
  Widget build(BuildContext context) {
    final feedCtrl  = context.watch<FeedController>();
    final storyCtrl = context.watch<StoryController>();
    final FeedState state = feedCtrl.state;

    // ── Story bar (ҳамеша дар боло) ─────────────────────────────────
    final storyBar = StoryBar(
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
    );

    // ── Боркунӣ ─────────────────────────────────────────────────────
    if (state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        storyBar,
        const Divider(color: Colors.white10, height: 1),
        const Expanded(child: Center(child: LoadingIndicator())),
      ]);
    }

    // ── Холӣ ────────────────────────────────────────────────────────
    if (!state.isLoading && state.posts.isEmpty) {
      return Column(children: [
        storyBar,
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await Navigator.pushNamed(context, AppRoutes.create);
                if (r == true && context.mounted) {
                  context.read<FeedController>().refresh();
                  onCreatePost?.call();
                }
              },
              child: const Text('Пост гузор'),
            ),
          ),
        ),
      ]);
    }

    // ── Лентаи асосӣ бо RefreshIndicator ────────────────────────────
    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: () => feedCtrl.refresh(),
      child: CustomScrollView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Story bar
          SliverToBoxAdapter(child: storyBar),
          SliverToBoxAdapter(
            child: const Divider(color: Colors.white10, height: 1),
          ),

          // ── "N та пости нав" banner — мисли Instagram ──────────────
          if (feedCtrl.pendingCount > 0)
            SliverToBoxAdapter(
              child: _NewPostsBanner(
                count: feedCtrl.pendingCount,
                onTap: () {
                  feedCtrl.flushPending();
                  // Ба боли рӯйхат бозгард
                  if (scroll.hasClients) {
                    scroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),

          // ── Постҳо ─────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.posts.length) {
                  // Footer: loader ё охир
                  return state.hasMore
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: LoadingIndicator()),
                        )
                      : const SizedBox(height: 40);
                }
                return PostCard(
                  post: state.posts[index],
                  isActive: isActive,
                );
              },
              childCount: state.posts.length + 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── "N та пости нав" banner ──────────────────────────────────────────
class _NewPostsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NewPostsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.neonBlue,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonBlue.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              count == 1
                  ? '1 пости нав'
                  : '$count та пости нав',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
