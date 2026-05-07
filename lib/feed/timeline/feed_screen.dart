import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../feed_repository.dart';
import 'feed_controller.dart';
import 'feed_state.dart';
import '../post/post_card.dart';
import '../post/post_card_skeleton.dart';
import '../../stories/story_bar.dart';
import '../../stories/story_group_viewer.dart';
import '../../stories/story_controller.dart';
import '../../stories/story_repository.dart';
import '../../models/story_model.dart';
import '../../core/api/api_client.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/services/user_session.dart';
import '../../notifications/notification_badge.dart';

import '../../core/ads/ads_manager.dart';
import '../../core/ads/feed_ad_card.dart';

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
  static const int _adEveryNPosts = 5;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
    NotificationService.startPolling();
    AdsManager.instance.init();
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
    final feedCtrl = context.watch<FeedController>();
    final state    = feedCtrl.state;
    final storyCtrl = context.watch<StoryController>();

    // Stories bar
    Widget storyBar = const SizedBox.shrink();
    if (storyCtrl.stories.isNotEmpty) {
      final groups = groupStoriesByUser(storyCtrl.stories);
      storyBar = StoryBar(
        stories: storyCtrl.stories,
        onTapGroup: (groupStories, index) {
          Navigator.of(context).push(PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => StoryGroupViewer(
              groups: groups,
              initialGroupIndex: index,
            ),
          ));
        },
      );
    }

    // Loading
    if (state.isLoading && state.posts.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(child: storyBar),
            const SliverToBoxAdapter(
                child: Divider(color: Color(0xFF1A1A1A), height: 1)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const PostCardSkeleton(),
                childCount: 5,
              ),
            ),
          ],
        ),
      );
    }

    // Error
    if (state.hasError && state.posts.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.grey, size: 48),
              const SizedBox(height: 12),
              Text(state.errorMessage ?? 'Хато рӯй дод',
                  style: const TextStyle(color: AppColors.grey)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: feedCtrl.refresh,
                child: const Text('Боз кӯшиш кун',
                    style: TextStyle(color: AppColors.neonBlue)),
              ),
            ],
          ),
        ),
      );
    }

    final posts      = state.posts;
    final blockSize  = _adEveryNPosts + 1;
    final adSlots    = posts.length ~/ _adEveryNPosts;
    final totalItems = posts.length + adSlots + 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (ctx, _) => [_buildAppBar(ctx)],
        body: RefreshIndicator(
          color: AppColors.neonBlue,
          backgroundColor: AppColors.surface,
          onRefresh: () => feedCtrl.refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: storyBar),
              const SliverToBoxAdapter(
                  child: Divider(color: Color(0xFF1A1A1A), height: 1)),
              if (feedCtrl.pendingCount > 0)
                SliverToBoxAdapter(
                  child: _NewPostsBanner(
                    count: feedCtrl.pendingCount,
                    onTap: feedCtrl.flushPending,
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, virtualIndex) {
                    // Loader / end
                    if (virtualIndex == totalItems - 1) {
                      return state.hasMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.neonBlue, strokeWidth: 2),
                              ),
                            )
                          : const SizedBox(height: 40);
                    }

                    final blockIndex = virtualIndex % blockSize;
                    final blockNum   = virtualIndex ~/ blockSize;

                    // Ad slot
                    if (blockIndex == _adEveryNPosts) {
                      final postsSoFar = blockNum * _adEveryNPosts + _adEveryNPosts;
                      if (postsSoFar <= posts.length) {
                        return const FeedAdCard();
                      }
                      return const SizedBox.shrink();
                    }

                    // Real post
                    final postIndex = blockNum * _adEveryNPosts + blockIndex;
                    if (postIndex >= posts.length) return const SizedBox.shrink();

                    return PostCard(
                      post:     posts[postIndex],
                      isActive: widget.isActive,
                    );
                  },
                  childCount: totalItems,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      floating: true,
      snap:    true,
      pinned:  false,
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
      title: const Text(
        'Raonson',
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w400,
          color: Colors.white,
          fontFamily: 'RaonsonFont',
          letterSpacing: 0.5,
          height: 1.1,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: NotificationBadge(
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Colors.white, size: 27),
              onPressed: () {
                NotificationService.markRead();
                Navigator.pushNamed(context, AppRoutes.notifications);
              },
            ),
          ),
        ),
      ],
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              count == 1 ? '1 пости нав' : '$count та пости нав',
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
