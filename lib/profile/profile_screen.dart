import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../app/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/verified_badge.dart';
import 'profile_controller.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileController _ctrl;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _ctrl = ProfileController(userId: widget.userId);
    _ctrl.loadProfile();
    _tab = TabController(length: 2, vsync: this);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      );
    }

    final user = _ctrl.profile;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('User not found', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 48, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // ── Avatar + stats row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(imageUrl: user.avatar, size: 82, glowBorder: true),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (user.verified) ...[
                                  const SizedBox(width: 6),
                                  const VerifiedBadge(size: 16),
                                ],
                              ],
                            ),
                            if (user.bio != null && user.bio!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                user.bio!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            // Stats row
                            Row(
                              children: [
                                _stat(user.postsCount, 'Posts'),
                                const SizedBox(width: 20),
                                _stat(user.followersCount, 'Followers'),
                                const SizedBox(width: 20),
                                _stat(user.followingCount, 'Following'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Follow / Edit buttons ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _ctrl.toggleFollow,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: user.isFollowing
                                  ? AppColors.surface
                                  : AppColors.neonBlue,
                              boxShadow: !user.isFollowing
                                  ? [
                                      BoxShadow(
                                        color: AppColors.neonBlue.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                user.isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: user.isFollowing
                                      ? Colors.white70
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_outlined,
                            color: Colors.white70, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_outlined,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),

                // ── Highlights (story bubbles) ──
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      'Travel', 'Beach', 'Fitness', 'Food'
                    ].asMap().entries.map((e) {
                      final colors = [
                        [const Color(0xFF4B7BEC), const Color(0xFF3867D6)],
                        [const Color(0xFFFFA502), const Color(0xFFFF6348)],
                        [const Color(0xFF7bed9f), const Color(0xFF2ed573)],
                        [const Color(0xFFff4757), const Color(0xFFff6b81)],
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: colors[e.key % colors.length],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.image,
                                  color: Colors.white54, size: 26),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ── Tab bar ──
                TabBar(
                  controller: _tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded)),
                    Tab(icon: Icon(Icons.play_circle_outline_rounded)),
                  ],
                  indicatorColor: AppColors.neonBlue,
                  labelColor: AppColors.neonBlue,
                  unselectedLabelColor: Colors.white38,
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _PostGrid(posts: _ctrl.posts),
            _ReelGrid(reels: _ctrl.reels),
          ],
        ),
      ),
    );
  }

  Widget _stat(int count, String label) {
    return Column(
      children: [
        Text(
          _fmt(count),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _PostGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _PostGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts yet', style: TextStyle(color: Colors.white38)),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final url = posts[i].media.isNotEmpty
            ? posts[i].media.first['url'] ?? ''
            : '';
        return url.isEmpty
            ? Container(color: AppColors.card)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.card),
              );
      },
    );
  }
}

class _ReelGrid extends StatelessWidget {
  final List<ReelModel> reels;
  const _ReelGrid({required this.reels});

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return const Center(
        child: Text('No reels yet', style: TextStyle(color: Colors.white38)),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: reels.length,
      itemBuilder: (_, i) => Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.card),
          const Center(
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white54, size: 32),
          ),
        ],
      ),
    );
  }
}
