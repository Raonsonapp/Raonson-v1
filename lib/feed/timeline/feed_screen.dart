import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import '../../notifications/notification_badge.dart';
import '../../widgets/avatar.dart';
import '../../core/ui/app_icons.dart';
import '../../shop/shop_screen.dart';

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

// ─────────────────────────────────────────────────────────────────────
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
    AnalyticsService.instance.logEvent(AnalyticsEvents.feedView);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      context.read<FeedController>().loadMore();
    }
  }

  @override
  void dispose() {
    NotificationService.stopPolling();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // SliverAppBar — пинҳон мешавад вақти scroll — мисли Instagram
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            floating: true,   // зуд намоён мешавад
            snap: true,       // яклухт пайдо мешавад
            pinned: false,    // scroll кунӣ пинҳон мешавад
            leadingWidth: 100,
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: SvgPicture.asset('assets/icons/upload.svg',
                  width: 26, height: 26,
                  colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
                onPressed: () async {
                  final r = await Navigator.pushNamed(ctx, AppRoutes.create);
                  if (r == true && ctx.mounted) {
                    ctx.read<FeedController>().refresh();
                    widget.onCreatePost?.call();
                  }
                },
              ),
              // Магоза — тарафи чапи Raonson (мисли дархост)
              IconButton(
                icon: Icon(AppIcons.storefront_rounded,
                    color: AppColors.textPrimary, size: 21),
                tooltip: 'Магоза',
                onPressed: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const ShopScreen())),
              ),
            ]),
            title: Text('Raonson', style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
              fontFamily: 'RaonsonFont', letterSpacing: 0.5, height: 1.1,
            )),
            centerTitle: true, // лого дар марказ — мисли скриншоти Instagram
            actions: [
              IconButton(
                icon: SvgPicture.asset('assets/icons/friends.svg',
                    width: 25, height: 25,
                    colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
                onPressed: () => Navigator.pushNamed(ctx, '/friends'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: NotificationBadge(
                  child: IconButton(
                    icon: SvgPicture.asset('assets/icons/notifications.svg',
                        width: 25, height: 25,
                        colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
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
        body: _FeedBody(isActive: widget.isActive, onCreatePost: widget.onCreatePost),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
class _FeedBody extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onCreatePost;
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

  // Story bar — unseen first
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

    // Build groups for StoryGroupViewer
    final allGroups = groupStoriesByUser(sortedStories);
    // Add my group at front if exists

    final storyBar = StoryBar(
      stories:   sortedStories,
      myStories: storyCtrl.myStories,
      myAvatar:  UserSession.avatar,
      onTapGroup: (group, idx) {
        final groups = allGroups;
        final groupIdx = groups.indexWhere(
            (g) => g.first.user.id == group.first.user.id);
        if (groupIdx < 0) {
          // Гурӯҳ дар рӯйхати умумӣ нест (мас. сториси худи ман) —
          // ҳамон гурӯҳро бо ҳамаи сторисҳояш мекушоем.
          _openStoryGroup(context, [group], 0);
        } else {
          _openStoryGroup(context, groups, groupIdx);
        }
      },
      onTap: (s) {
        // Fallback: open single story as group
        _openStoryGroup(context, [[s]], 0);
      },
      onAddStory: () async {
        final ok = await Navigator.pushNamed(context, '/create-story');
        if (context.mounted) {
          context.read<StoryController>().loadStories();
          if (ok == true) context.read<FeedController>().refresh();
        }
      },
    );

    // ── Skeleton loading ─────────────────────────────────────────
    if (state.isLoading && state.posts.isEmpty) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: FeedSkeleton(),
      );
    }

    // ── Offline banner ─────────────────────────────────────────
    final offlineBanner = feedCtrl.isOffline
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.card,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(AppIcons.wifi_off, color: AppColors.textFaint, size: 14),
              const SizedBox(width: 6),
              Text('Оффлайн — кэш нишон дода мешавад',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => feedCtrl.refresh(),
                child: const Text('Такрор',
                  style: TextStyle(color: AppColors.neonBlue,
                      fontSize: 12, fontWeight: FontWeight.w600))),
            ]))
        : const SizedBox.shrink();

    // ── Empty state ─────────────────────────────────────────────
    if (!state.isLoading && state.posts.isEmpty && !state.hasError) {
      return RefreshIndicator(
        color: AppColors.neonBlue, backgroundColor: AppColors.surface,
        onRefresh: () => feedCtrl.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: storyBar),
            SliverToBoxAdapter(
                child: Divider(color: AppColors.card, height: 1)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.photo_camera_outlined,
                      size: 64, color: AppColors.dividerFaint),
                  const SizedBox(height: 16),
                  Text('Ҳоло постҳо нест',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 16)),
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
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                    child: const Text('Пост гузор')),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: _SuggestedUsersList()),
          ],
        ),
      );
    }

    // ── Error state бо Retry ────────────────────────────────────
    if (state.hasError && state.posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.neonBlue, backgroundColor: AppColors.surface,
        onRefresh: () => feedCtrl.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: storyBar),
            SliverToBoxAdapter(
                child: Divider(color: AppColors.card, height: 1)),
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.cloud_off_outlined,
                      size: 64, color: AppColors.dividerFaint),
                  const SizedBox(height: 16),
                  Text('Пайвастшавӣ мумкин нест',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Интернетро санҷед ва такрор кӯшиш кунед',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 13),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => feedCtrl.loadInitialFeed(),
                    icon: const Icon(AppIcons.refresh_rounded),
                    label: const Text('Такрор кӯшиш'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      foregroundColor: AppColors.textPrimary,
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

    // ── Main feed ───────────────────────────────────────────────
    return RefreshIndicator(
      color: AppColors.neonBlue,
      backgroundColor: AppColors.surface,
      onRefresh: () => feedCtrl.refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: offlineBanner),
          SliverToBoxAdapter(child: storyBar),
          SliverToBoxAdapter(
              child: Divider(color: AppColors.card, height: 1)),
          if (feedCtrl.pendingCount > 0)
            SliverToBoxAdapter(
              child: _NewPostsBanner(
                count: feedCtrl.pendingCount,
                onTap: () {
                  feedCtrl.flushPending();
                  // scroll ба боло
                },
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.posts.length) {
                  return state.hasMore
                      ? const Padding(padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(
                              color: AppColors.neonBlue, strokeWidth: 2)))
                      : const SizedBox(height: 40);
                }
                return PostCard(
                  key: ValueKey(state.posts[index].id), // ҳар пост state-и худаш
                  post: state.posts[index],
                  isActive: isActive,
                  onDeleted: () => context.read<FeedController>()
                      .removePost(state.posts[index].id),
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

// ── New Posts Banner ─────────────────────────────────────────────────
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
            Icon(AppIcons.arrow_upward_rounded, color: AppColors.textPrimary, size: 16),
            const SizedBox(width: 6),
            Text(count == 1 ? '1 пости нав' : '$count та пости нав',
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
      ),
    );
  }
}

// ── Suggested users (when feed is empty) ─────────────────────────────
class _SuggestedUsersList extends StatefulWidget {
  const _SuggestedUsersList();

  @override
  State<_SuggestedUsersList> createState() => _SuggestedUsersListState();
}

class _SuggestedUser {
  final String id;
  final String username;
  final String avatar;
  final bool verified;
  bool following;
  _SuggestedUser({
    required this.id,
    required this.username,
    required this.avatar,
    required this.verified,
    this.following = false,
  });
}

class _SuggestedUsersListState extends State<_SuggestedUsersList> {
  List<_SuggestedUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/users/suggested?limit=8');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['users'] as List?) ?? [];
        final users = list.map((u) {
          final m = u as Map<String, dynamic>;
          return _SuggestedUser(
            id:       (m['_id'] ?? '').toString(),
            username: (m['username'] ?? '').toString(),
            avatar:   (m['avatar'] ?? '').toString(),
            verified: m['verified'] == true,
          );
        }).where((u) => u.id.isNotEmpty).toList();
        if (mounted) setState(() { _users = users; _loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _follow(_SuggestedUser u) async {
    setState(() => u.following = true);
    try {
      await ApiClient.instance.post('/follow/${u.id}');
    } catch (_) {
      if (mounted) setState(() => u.following = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _users.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Барои шумо тавсия',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final u = _users[i];
              return Container(
                width: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Avatar(imageUrl: u.avatar, size: 56),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(u.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        if (u.verified) ...[
                          const SizedBox(width: 3),
                          const Icon(AppIcons.verified_rounded,
                              fill: 1, color: Color(0xFF00C853), size: 13),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: u.following ? null : () => _follow(u),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: u.following
                              ? AppColors.surface
                              : AppColors.neonBlue,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(u.following ? 'Пайравӣ ✓' : 'Пайравӣ',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
