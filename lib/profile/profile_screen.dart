import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_theme.dart';
import '../core/services/user_session.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import '../widgets/avatar.dart';
import '../widgets/verified_badge.dart';
import '../chat/room/chat_room_screen.dart';
import 'edit/edit_profile_screen.dart';
import 'profile_controller.dart';
import '../settings/settings_screen.dart';
import 'profile_repository.dart';
import '../core/api/api_client.dart';

// ═══════════════════════════════════════════════════════════════════
//  ProfileScreen — Instagram услуби
// ═══════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileController _ctrl;
  late final TabController      _tab;

  @override
  void initState() {
    super.initState();
    _ctrl = ProfileController(userId: widget.userId);
    _ctrl.loadProfile();
    _tab = TabController(length: 2, vsync: this);
    _ctrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  bool get _isMe =>
      widget.userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == _ctrl.profile?.id);

  // ── Share ──────────────────────────────────────────────────────
  void _share() {
    final u = _ctrl.profile;
    if (u == null) return;
    Clipboard.setData(ClipboardData(text: 'raonson://profile/${u.username}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Профил нусхабардорӣ шуд'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ═══ BUILD ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(
            color: AppColors.neonBlue, strokeWidth: 2)),
      );
    }

    final user = _ctrl.profile;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          leading: const BackButton(color: Colors.white),
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_off_rounded, size: 56,
                color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('Корбар ёфт нашуд',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 15)),
            if (_ctrl.error != null) ...[
              const SizedBox(height: 8),
              Text(_ctrl.error!,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.25), fontSize: 11),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: _ctrl.loadProfile,
              child: const Text('Дубора кӯшиш кун',
                  style: TextStyle(color: AppColors.neonBlue)),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader(user)),
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

  Widget _buildHeader(UserModel user) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── TOP BAR ─────────────────────────────────────────────────
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            if (Navigator.canPop(context))
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.maybePop(context),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Text(user.username,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            // Share button
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 20),
              onPressed: _share,
            ),
            // More → settings
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ]),
        ),
      ),

      // ── AVATAR + STATS ───────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Stack(children: [
              Avatar(imageUrl: user.avatar, size: 80, glowBorder: user.verified),
              // Verified dot
              if (user.verified)
                Positioned(bottom: 2, right: 2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bg,
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: Color(0xFF00C853), size: 20),
                  ),
                ),
            ]),
            const SizedBox(width: 28),
            // Stats
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBtn(
                    count: user.postsCount,
                    label: 'Постҳо',
                    onTap: null,
                  ),
                  _StatBtn(
                    count: user.followersCount,
                    label: 'Обунагарон',
                    onTap: () => _showFollowers(user.id),
                  ),
                  _StatBtn(
                    count: user.followingCount,
                    label: 'Обуна',
                    onTap: () => _showFollowing(user.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── BIO ──────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name + verified
          Row(children: [
            Text(user.username,
                style: const TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.bold)),
            if (user.verified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded,
                  color: Color(0xFF00C853), size: 15),
            ],
          ]),
          if ((user.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(user.bio!,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13)),
          ],
        ]),
      ),

      // ── BUTTONS ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: _isMe
            ? _OwnButtons(
                onEdit: () async {
                  final updated = await Navigator.push<bool>(context,
                      MaterialPageRoute(builder: (_) =>
                          EditProfileScreen(userId: widget.userId)));
                  if (updated == true && mounted) _ctrl.loadProfile();
                },
                onShare: _share,
                onVerify: !user.verified ? _showVerifySheet : null,
              )
            : _OtherButtons(
                isFollowing: user.isFollowing,
                onFollow:    _ctrl.toggleFollow,
                onMessage:   () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(peer: user)));
                },
              ),
      ),

      // ── TAB BAR ──────────────────────────────────────────────────
      const SizedBox(height: 8),
      TabBar(
        controller:           _tab,
        tabs: const [
          Tab(icon: Icon(Icons.grid_on_rounded)),
          Tab(icon: Icon(Icons.play_circle_outline_rounded)),
        ],
        indicatorColor:       AppColors.neonBlue,
        indicatorWeight:      2,
        labelColor:           AppColors.neonBlue,
        unselectedLabelColor: Colors.white24,
        dividerColor:         Colors.white10,
      ),
    ]);
  }

  // ── Обунагарон / Обуна ───────────────────────────────────────
  void _showFollowers(String userId) => _showUserList('Обунагарон', userId, true);
  void _showFollowing(String userId) => _showUserList('Обуна',      userId, false);

  void _showUserList(String title, String userId, bool isFollowers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserListSheet(
          title: title, userId: userId, isFollowers: isFollowers),
    );
  }

  // ── Тасдиқи профил ($2) ──────────────────────────────────────
  void _showVerifySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VerifySheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Stat Button (постҳо / обунагарон / обуна)
// ─────────────────────────────────────────────────────────────────
class _StatBtn extends StatelessWidget {
  final int         count;
  final String      label;
  final VoidCallback? onTap;
  const _StatBtn({required this.count, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Text(_fmt(count),
          style: const TextStyle(color: Colors.white,
              fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.55), fontSize: 11.5)),
    ]),
  );

  String _fmt(int n) {
    if (n >= 1000000) return '${(n/1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────
//  Own profile buttons — Edit | Share | Verify (if not verified)
// ─────────────────────────────────────────────────────────────────
class _OwnButtons extends StatelessWidget {
  final VoidCallback  onEdit;
  final VoidCallback  onShare;
  final VoidCallback? onVerify;
  const _OwnButtons({required this.onEdit, required this.onShare, this.onVerify});

  @override
  Widget build(BuildContext context) => Row(children: [
    // Edit profile
    Expanded(
      child: _Btn(
        label: 'Таҳрир',
        icon:  Icons.edit_rounded,
        onTap: onEdit,
      ),
    ),
    const SizedBox(width: 8),
    // Share profile
    Expanded(
      child: _Btn(
        label: 'Мубодила',
        icon:  Icons.share_rounded,
        onTap: onShare,
      ),
    ),
    if (onVerify != null) ...[
      const SizedBox(width: 8),
      // Get Verified $2
      GestureDetector(
        onTap: onVerify,
        child: Container(
          height: 36, width: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF00C853).withOpacity(0.5)),
          ),
          child: const Icon(Icons.verified_rounded,
              color: Color(0xFF00C853), size: 20),
        ),
      ),
    ],
  ]);
}

// ─────────────────────────────────────────────────────────────────
//  Other profile buttons — Follow | Message
// ─────────────────────────────────────────────────────────────────
class _OtherButtons extends StatelessWidget {
  final bool         isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  const _OtherButtons({
    required this.isFollowing,
    required this.onFollow,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: GestureDetector(
        onTap: onFollow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          decoration: BoxDecoration(
            color:         isFollowing ? Colors.transparent : AppColors.neonBlue,
            borderRadius:  BorderRadius.circular(10),
            border:        isFollowing
                ? Border.all(color: Colors.white24)
                : null,
            boxShadow: !isFollowing ? [
              BoxShadow(color: AppColors.neonBlue.withOpacity(0.35),
                  blurRadius: 10)
            ] : null,
          ),
          child: Center(
            child: Text(
              isFollowing ? 'Обунашуда' : 'Обуна',
              style: TextStyle(
                color: isFollowing ? Colors.white70 : Colors.white,
                fontWeight: FontWeight.bold, fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    ),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: onMessage,
      child: Container(
        height: 36, width: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.surface,
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: Colors.white70, size: 18),
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────
//  Generic outline button
// ─────────────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color:        AppColors.surface,
        border:       Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 15),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Post grid
// ─────────────────────────────────────────────────────────────────
class _PostGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _PostGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.grid_off_rounded, size: 48,
              color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 10),
          Text('Ҳанӯз пост нест',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14)),
        ]),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final url = posts[i].media.isNotEmpty
            ? posts[i].media.first['url'] ?? '' : '';
        return url.isEmpty
            ? Container(color: AppColors.card)
            : CachedNetworkImage(
                imageUrl: url, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => Container(color: AppColors.card),
              );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Reel grid
// ─────────────────────────────────────────────────────────────────
class _ReelGrid extends StatelessWidget {
  final List<ReelModel> reels;
  const _ReelGrid({required this.reels});

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.videocam_off_rounded, size: 48,
              color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 10),
          Text('Ҳанӯз рил нест',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14)),
        ]),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 0.7),
      itemCount: reels.length,
      itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
        Container(color: AppColors.card),
        const Center(child: Icon(Icons.play_circle_outline_rounded,
            color: Colors.white38, size: 32)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Followers / Following bottom sheet
// ─────────────────────────────────────────────────────────────────
class _UserListSheet extends StatefulWidget {
  final String title;
  final String userId;
  final bool   isFollowers;
  const _UserListSheet({
    required this.title, required this.userId, required this.isFollowers});

  @override
  State<_UserListSheet> createState() => _UserListSheetState();
}

class _UserListSheetState extends State<_UserListSheet> {
  final _repo = ProfileRepository(ApiClient.instance);
  List<UserModel> _list = [];
  bool            _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = widget.isFollowers
        ? await _repo.getFollowers(widget.userId)
        : await _repo.getFollowing(widget.userId);
    if (mounted) setState(() { _list = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.65,
    decoration: const BoxDecoration(
      color: Color(0xFF0D1117),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Column(children: [
      const SizedBox(height: 10),
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 14),
      Text(widget.title,
          style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Divider(color: Colors.white10),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: AppColors.neonBlue, strokeWidth: 2))
            : _list.isEmpty
                ? Center(child: Text('Ҳанӯз ${widget.title.toLowerCase()} нест',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 14)))
                : ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (_, i) {
                      final u = _list[i];
                      return ListTile(
                        leading: Avatar(imageUrl: u.avatar, size: 44),
                        title: Row(children: [
                          Text(u.username,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          if (u.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF00C853), size: 14),
                          ],
                        ]),
                        subtitle: u.bio != null && u.bio!.isNotEmpty
                            ? Text(u.bio!,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: u.id)));
                        },
                      );
                    },
                  ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Verified Sheet — $2
// ─────────────────────────────────────────────────────────────────
class _VerifySheet extends StatelessWidget {
  const _VerifySheet();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    decoration: const BoxDecoration(
      color: Color(0xFF0D1117),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),

      // Icon
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00C853).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4),
              width: 2),
        ),
        child: const Icon(Icons.verified_rounded,
            color: Color(0xFF00C853), size: 34),
      ),
      const SizedBox(height: 16),

      const Text('Профили тасдиқшуда',
          style: TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Нишони сабз нишон медиҳад ки профил воқеӣ аст',
          style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),

      // Features
      ...[
        ('Нишони тасдиқшудаи сабз', Icons.check_circle_outline_rounded),
        ('Дар ҷустуҷӯ болотар намоиш',Icons.search_rounded),
        ('Ҳифзи профил аз ҷаъл',     Icons.security_rounded),
      ].map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(e.$2, color: const Color(0xFF00C853), size: 18),
          const SizedBox(width: 10),
          Text(e.$1,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 13)),
        ]),
      )),
      const SizedBox(height: 24),

      // Price button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Тасдиқи профил тавассути барнома'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Тасдиқ кун — \$2 / моҳ',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    ]),
  );
}
