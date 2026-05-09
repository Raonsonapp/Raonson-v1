// lib/feed/timeline/feed_screen.dart
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            floating: true,
            snap: true,
            pinned: false,
            // ✅ + icon чапда
            leading: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () async {
                final r = await Navigator.pushNamed(ctx, AppRoutes.create);
                if (r == true && ctx.mounted) {
                  ctx.read<FeedController>().refresh();
                  widget.onCreatePost?.call();
                }
              },
            ),
            title: const Text('Raonson', style: TextStyle(
              fontSize: 38, fontWeight: FontWeight.w400, color: Colors.white,
              fontFamily: 'RaonsonFont', letterSpacing: 0.5, height: 1.1,
            )),
            centerTitle: true,
            actions: [
              // ✅ Friends icon (мисли Facebook)
              IconButton(
                icon: const Icon(Icons.people_outline_rounded,
                    color: Colors.white, size: 26),
                onPressed: () =>
                    Navigator.pushNamed(ctx, '/friends'),
              ),
              // ✅ Notifications
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: NotificationBadge(
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 27),
                    onPressed: () {
                      NotificationService.markRead();
                      Navigator.pushNamed(ctx, AppRoutes.notifications);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
        body: _FeedBody(
            isActive: widget.isActive, onCreatePost: widget.onCreatePost),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onCreatePost;
  static const int _adEvery = 5;
  const _FeedBody({this.isActive = true, this.onCreatePost});

  Future<void> _openStoryGroup(
      BuildContext context,
      List<List<StoryModel>> groups,
      int initialGroupIndex) async {
    final storyCtrl = context.read<StoryController>();
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StoryGroupViewer(
          groups: groups,
          initialGroupIndex: initialGroupIndex,
          onViewed: storyCtrl.markViewed,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  List<StoryModel> _sortStories(List<StoryModel> stories) {
    final unseen = stories.where((s) => !s.viewed).toList();
    final seen   = stories.where((s) =>  s.viewed).toList();
    return [...unseen, ...seen];
  }

  @override
  Widget build(BuildContext context) {
    final feedCtrl  = context.watch<FeedController>();
    final storyCtrl = context.watch<StoryController>();
    final FeedState state = feedCtrl.state;
    final sortedStories = _sortStories(storyCtrl.stories);
    final allGroups = groupStoriesByUser(sortedStories);

    final storyBar = StoryBar(
      stories:   sortedStories,
      myStories: storyCtrl.myStories,
      myAvatar:  UserSession.avatar,
      onTapGroup: (group, idx) {
        final groupIdx = allGroups.indexWhere(
            (g) => g.first.user.id == group.first.user.id);
        _openStoryGroup(
            context, allGroups, groupIdx.clamp(0, allGroups.length - 1));
      },
      onTap: (s) => _openStoryGroup(context, [[s]], 0),
      onAddStory: () async {
        final ok = await Navigator.pushNamed(context, '/create-story');
        if (context.mounted) {
          context.read<StoryController>().loadStories();
          if (ok == true) context.read<FeedController>().refresh();
        }
      },
    );

    // ── Skeleton ─────────────────────────────────────────────────
    if (state.isLoading && state.posts.isEmpty) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: FeedSkeleton(),
      );
    }

    // ── Empty ─────────────────────────────────────────────────────
    if (!state.isLoading && state.posts.isEmpty && !state.hasError) {
      return RefreshIndicator(
        color: AppColors.neonBlue, backgroundColor: AppColors.surface,
        onRefresh: () => feedCtrl.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: storyBar),
            const SliverToBoxAdapter(
                child: Divider(color: Color(0xFF1A1A1A), height: 1)),
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_outlined,
                      size: 64, color: Colors.white12),
                  const SizedBox(height: 16),
                  const Text('Ҳоло постҳо нест',
                      style: TextStyle(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final r = await Navigator.pushNamed(
                          context, AppRoutes.create);
                      if (r == true && context.mounted) {
                        context.read<FeedController>().refresh();
                        onCreatePost?.call();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                    child: const Text('Пост гузор')),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    // ── Error ─────────────────────────────────────────────────────
    if (state.hasError && state.posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.neonBlue, backgroundColor: AppColors.surface,
        onRefresh: () => feedCtrl.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: storyBar),
            const SliverToBoxAdapter(
                child: Divider(color: Color(0xFF1A1A1A), height: 1)),
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 64, color: Colors.white12),
                  const SizedBox(height: 16),
                  const Text('Пайвастшавӣ мумкин нест',
                      style: TextStyle(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => feedCtrl.loadInitialFeed(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Такрор кӯшиш'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12))),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    // ── Main feed бо Ad ───────────────────────────────────────────
    final posts     = state.posts;
    final blockSize = _adEvery + 1;
    final adSlots   = posts.length ~/ _adEvery;
    final total     = posts.length + adSlots + 1;

    return RefreshIndicator(
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
                if (virtualIndex == total - 1) {
                  return state.hasMore
                      ? const Padding(padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(
                              color: AppColors.neonBlue, strokeWidth: 2)))
                      : const SizedBox(height: 40);
                }

                final blockIndex = virtualIndex % blockSize;
                final blockNum   = virtualIndex ~/ blockSize;

                // Ad slot
                if (blockIndex == _adEvery) {
                  final postsSoFar = blockNum * _adEvery + _adEvery;
                  if (postsSoFar <= posts.length) return const FeedAdCard();
                  return const SizedBox.shrink();
                }

                final postIndex = blockNum * _adEvery + blockIndex;
                if (postIndex >= posts.length) return const SizedBox.shrink();

                return PostCard(
                  post: posts[postIndex],
                  isActive: isActive,
                );
              },
              childCount: total,
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
            end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(count == 1 ? '1 пости нав' : '$count та пости нав',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
      ),
    );
  }
}

// ── Feed Skeleton ─────────────────────────────────────────────────────
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Stories skeleton
      SizedBox(height: 114, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          _shimmer(80, 80, radius: 40),
          const SizedBox(height: 5),
          _shimmer(60, 10),
        ]),
      )),
      const Divider(color: Color(0xFF1A1A1A), height: 1),
      ...List.generate(3, (_) => const PostCardSkeleton()),
    ]);
  }

  Widget _shimmer(double w, double h, {double radius = 8}) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
