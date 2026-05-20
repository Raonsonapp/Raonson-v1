// lib/profile/profile_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import '../widgets/verified_badge.dart';
import '../chat/room/chat_room_screen.dart';
import 'edit/edit_profile_screen.dart';
import 'profile_controller.dart';
import 'profile_repository.dart';
import 'profile_skeleton.dart';
import 'highlights_row.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool byUsername;
  const ProfileScreen({super.key, required this.userId, this.byUsername = false});
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
    _ctrl = ProfileController(
      userId: widget.userId,
      byUsername: widget.byUsername,
    );
    _ctrl.loadProfile();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 2 && _ctrl.taggedPosts.isEmpty) {
        _ctrl.loadTaggedPosts();
      }
    });
    _ctrl.addListener(() { if (mounted) { setState(() {}); } });
  }

  @override
  void dispose() { _ctrl.dispose(); _tab.dispose(); super.dispose(); }

  bool get _isMe =>
      widget.userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == _ctrl.profile?.id);

  // ── Top bar actions ─────────────────────────────────────────────
  void _share() {
    final u = _ctrl.profile;
    if (u == null) { return; }
    Clipboard.setData(ClipboardData(text: 'raonson://profile/${u.username}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Профил нусхабардорӣ шуд'),
        duration: Duration(seconds: 2)));
  }

  void _showOtherMenu() {
    final u = _ctrl.profile;
    if (u == null) { return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: Icon(u.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
              color: u.isBlocked ? Colors.greenAccent : Colors.redAccent),
          title: Text(u.isBlocked ? '${u.username} блокро бардор' : '${u.username}-ро блок кун',
              style: TextStyle(color: u.isBlocked ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 16, fontWeight: FontWeight.w500)),
          onTap: () { Navigator.pop(context); _confirmBlock(u.isBlocked); }),
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.orange),
          title: const Text('Шикоят кун', style: TextStyle(color: Colors.orange, fontSize: 16)),
          onTap: () { Navigator.pop(context); _reportUser(); }),
        ListTile(
          leading: const Icon(Icons.link, color: Colors.white),
          title: const Text('Линкро нусха кун', style: TextStyle(color: Colors.white, fontSize: 16)),
          onTap: () { Navigator.pop(context); _share(); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _confirmBlock(bool isCurrentlyBlocked) {
    final u = _ctrl.profile!;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Text(isCurrentlyBlocked ? 'Блокро бардор?' : '${u.username}-ро блок кун?',
          style: const TextStyle(color: Colors.white)),
      content: Text(isCurrentlyBlocked
          ? '${u.username} барнома-и шуморо дида метавонад.'
          : '${u.username} шуморо дида наметавонад ва шумо онро.',
          style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
        TextButton(
          onPressed: () { Navigator.pop(context); _ctrl.toggleBlock(); },
          child: Text(isCurrentlyBlocked ? 'Бардор' : 'Блок кун',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  void _reportUser() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Шикоят фиристода шуд')));
  }

  Future<void> _launchWebsite(String url) async {
    String u = url.startsWith('http') ? url : 'https://$url';
    if (await canLaunchUrl(Uri.parse(u))) {
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    }
  }

  // ── Post context menu ────────────────────────────────────────────
  void _showPostMenu(PostModel post) {
    if (!_isMe) { return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: Icon(post.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: Colors.white),
          title: Text(post.isPinned ? '📌 Сабтро бардор' : '📌 Профилда сабт кун',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          onTap: () { Navigator.pop(context); _ctrl.togglePinPost(post); }),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Нест кун', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          onTap: () { Navigator.pop(context); _confirmDeletePost(post); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _confirmDeletePost(PostModel post) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text('Нест кардан?', style: TextStyle(color: Colors.white)),
      content: const Text('Ин пост тамоман нест мешавад.',
          style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
        TextButton(
          onPressed: () { Navigator.pop(context); _ctrl.deletePost(post); },
          child: const Text('Нест кун',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  // ── Mutual followers text ────────────────────────────────────────
  String _mutualText(UserModel u) {
    if (u.mutualCount == 0) { return ''; }
    if (u.mutualNames.isEmpty) { return '${u.mutualCount} умумӣ пайрав'; }
    if (u.mutualCount == 1) { return '${u.mutualNames.first} пайрав мешавад'; }
    if (u.mutualCount == 2) {
      return '${u.mutualNames.first} ва ${u.mutualNames.last} пайрав мешаванд';
    }
    return '${u.mutualNames.first}, ${u.mutualNames.last} ва '
        '${u.mutualCount - 2} нафари дигар';
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) { return const ProfileSkeleton(); }

    final user = _ctrl.profile;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, elevation: 0,
            leading: const BackButton(color: Colors.white)),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_off_rounded, size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('Корбар ёфт нашуд',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
          if (_ctrl.error != null)
            Padding(padding: const EdgeInsets.all(12),
                child: Text(_ctrl.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
          TextButton(onPressed: _ctrl.loadProfile,
              child: const Text('Дубора', style: TextStyle(color: AppColors.neonBlue))),
        ])));
    }

    final avatarUrl = user.avatar.isNotEmpty ? user.avatar
        : (_isMe ? (UserSession.avatar ?? '') : '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP BAR ───────────────────────────────────────────
            SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                if (Navigator.canPop(context))
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context))
                else const SizedBox(width: 4),
                Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(user.username,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
                  if (user.verified) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFF00C853), size: 16),
                  ],
                ])),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                  onPressed: _share),
                _isMe
                    ? IconButton(
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen())))
                    : IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 22),
                        onPressed: _showOtherMenu),
              ]),
            )),

            // ── AVATAR + STATS ────────────────────────────────────
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                _AvatarW(url: avatarUrl, size: 86),
                const SizedBox(width: 24),
                Expanded(child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(count: user.postsCount, label: 'Постҳо'),
                    _Stat(count: user.followersCount, label: 'Пайравон',
                        onTap: () => _showList('Пайравон', user.id, true)),
                    _Stat(count: user.followingCount, label: 'Пайравӣ',
                        onTap: () => _showList('Пайравӣ', user.id, false)),
                  ])),
              ])),

            // ── FULL NAME ─────────────────────────────────────────
            if ((user.fullName ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(user.fullName!,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.bold))),

            // ── BIO ───────────────────────────────────────────────
            if ((user.bio ?? '').isNotEmpty)
              Padding(padding: EdgeInsets.fromLTRB(
                  16, (user.fullName ?? '').isNotEmpty ? 4 : 10, 16, 0),
                child: Text(user.bio!,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 13.5, height: 1.4))),

            // ── WEBSITE ───────────────────────────────────────────
            if ((user.website ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                child: GestureDetector(
                  onTap: () => _launchWebsite(user.website!),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.link_rounded, color: AppColors.neonBlue, size: 14),
                    const SizedBox(width: 5),
                    Text(user.website!,
                        style: const TextStyle(color: AppColors.neonBlue,
                            fontSize: 13.5, fontWeight: FontWeight.w500)),
                  ]))),

            // ── HIGHLIGHTS ────────────────────────────────────────
            const SizedBox(height: 12),
            HighlightsRow(
              highlights: _ctrl.highlights,
              isMe:       _isMe,
              onAdd:      _isMe ? () {} : null,
            ),

            // ── BUTTONS ───────────────────────────────────────────
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: _isMe
                  ? _OwnBtns(
                      onEdit: () async {
                        final ok = await Navigator.push<bool>(context,
                            MaterialPageRoute(builder: (_) =>
                                EditProfileScreen(userId: widget.userId)));
                        if (ok == true && mounted) { _ctrl.loadProfile(); }
                      },
                      onShare: _share,
                      onVerify: !user.verified ? _verifySheet : null)
                  : _OtherBtns(
                      isFollowing:       user.isFollowing,
                      isPrivate:         user.isPrivate,
                      followRequestSent: user.followRequestSent,
                      onFollow:   _ctrl.toggleFollow,
                      onMessage:  () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(peer: user))))),

            // ── MUTUAL FOLLOWERS ──────────────────────────────────
            if (!_isMe && _mutualText(user).isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  const Icon(Icons.people_outline_rounded,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Flexible(child: Text(_mutualText(user),
                      style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                      maxLines: 2)),
                ])),

            // ── TABS ──────────────────────────────────────────────
            const SizedBox(height: 12),
            TabBar(
              controller: _tab,
              tabs: const [
                Tab(icon: Icon(Icons.grid_on_rounded)),
                Tab(icon: Icon(Icons.play_circle_outline_rounded)),
                Tab(icon: Icon(Icons.person_pin_outlined)),
              ],
              indicatorColor:          Colors.white,
              indicatorWeight:         2,
              indicatorSize:           TabBarIndicatorSize.tab,
              labelColor:              Colors.white,
              unselectedLabelColor:    Colors.white24,
              dividerColor:            Colors.white10,
            ),
          ]))],
        body: TabBarView(controller: _tab, children: [
          _PostGrid(
            posts:       _ctrl.sortedPosts,
            isMe:        _isMe,
            onLongPress: _showPostMenu),
          _ReelGrid(reels: _ctrl.reels),
          _TaggedGrid(userId: _ctrl.profile?.id ?? widget.userId, ctrl: _ctrl),
        ]),
      ),
    );
  }

  void _showList(String title, String uid, bool followers) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserListSheet(
          title: title, userId: uid, isFollowers: followers));
  }

  void _verifySheet() => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VerifySheet());
}

// ── Avatar widget ─────────────────────────────────────────────────────
class _AvatarW extends StatelessWidget {
  final String url; final double size;
  const _AvatarW({required this.url, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
        color: AppColors.card,
        border: Border.all(color: Colors.white12)),
    child: ClipOval(child: url.isNotEmpty
        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
            width: size, height: size,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => Container(color: AppColors.card,
                child: Icon(Icons.person_rounded,
                    color: Colors.white38, size: size * .5)))
        : Container(color: AppColors.card,
            child: Icon(Icons.person_rounded,
                color: Colors.white38, size: size * .5))));
}

// ── Stat widget ───────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final int count; final String label; final VoidCallback? onTap;
  const _Stat({required this.count, required this.label, this.onTap});
  String _f(int n) {
    if (n >= 1000000) { return '${(n / 1e6).toStringAsFixed(1)}M'; }
    if (n >= 1000) { return '${(n / 1000).toStringAsFixed(1)}K'; }
    return '$n';
  }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Text(_f(count), style: const TextStyle(color: Colors.white,
          fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
    ]));
}

// ── Own buttons ───────────────────────────────────────────────────────
class _OwnBtns extends StatelessWidget {
  final VoidCallback onEdit, onShare;
  final VoidCallback? onVerify;
  const _OwnBtns({required this.onEdit, required this.onShare, this.onVerify});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _Btn(label: 'Таҳрири профил',
        icon: Icons.edit_rounded, onTap: onEdit)),
    const SizedBox(width: 8),
    Expanded(child: _Btn(label: 'Мубодила',
        icon: Icons.share_rounded, onTap: onShare)),
    if (onVerify != null) ...[
      const SizedBox(width: 8),
      GestureDetector(onTap: onVerify,
        child: Container(height: 36, width: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00C853).withOpacity(0.5))),
          child: const Icon(Icons.verified_rounded,
              color: Color(0xFF00C853), size: 20))),
    ],
  ]);
}

// ── Other user buttons with Follow Request ────────────────────────────
class _OtherBtns extends StatelessWidget {
  final bool isFollowing;
  final bool isPrivate;
  final bool followRequestSent;
  final VoidCallback onFollow, onMessage;
  const _OtherBtns({
    required this.isFollowing,
    required this.isPrivate,
    required this.followRequestSent,
    required this.onFollow,
    required this.onMessage,
  });

  String get _label {
    if (isFollowing) { return 'Пайравишуда'; }
    if (followRequestSent) { return 'Дархост фиристода шуд'; }
    return 'Пайравӣ';
  }

  Color get _bg {
    if (isFollowing || followRequestSent) { return Colors.transparent; }
    return Colors.white;
  }

  Color get _textColor {
    if (isFollowing || followRequestSent) { return Colors.white54; }
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: GestureDetector(
      onTap: followRequestSent ? null : onFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: (isFollowing || followRequestSent)
              ? Border.all(color: Colors.white24) : null),
        child: Center(child: Row(
          mainAxisSize: MainAxisSize.min, children: [
            if (followRequestSent && !isFollowing)
              const Padding(padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.hourglass_empty_rounded,
                    color: Colors.white54, size: 14)),
            Text(_label, style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold, fontSize: 13.5)),
          ])))),
    ),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: onMessage,
      child: Container(height: 36, width: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: AppColors.surface, border: Border.all(color: Colors.white12)),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: Colors.white70, size: 18))),
  ]);
}

// ── Generic button ────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 36,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
        color: AppColors.surface, border: Border.all(color: Colors.white12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 15),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis)),
      ])));
}

// ── Post grid with pinned + long press ────────────────────────────────
class _PostGrid extends StatelessWidget {
  final List<PostModel> posts;
  final bool isMe;
  final void Function(PostModel) onLongPress;
  const _PostGrid({required this.posts, required this.isMe,
      required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const _EmptyState(
        icon: Icons.grid_off_rounded, label: 'Ҳанӯз пост нест');

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final post = posts[i];
        final url  = post.media.isNotEmpty
            ? (post.media.first['url'] ?? '') : '';
        return GestureDetector(
          onTap: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _PostSheet(posts: posts, idx: i)),
          onLongPress: isMe ? () => onLongPress(post) : null,
          child: Stack(fit: StackFit.expand, children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(color: AppColors.card))
                : Container(color: AppColors.card,
                    child: const Icon(Icons.image_outlined,
                        color: Colors.white24, size: 28)),
            if (post.media.length > 1)
              const Positioned(top: 6, right: 6,
                child: Icon(Icons.collections_rounded, color: Colors.white,
                    size: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            if (post.isPinned)
              const Positioned(top: 6, left: 6,
                child: Icon(Icons.push_pin_rounded, color: Colors.white,
                    size: 15, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ]));
      });
  }
}

// ── Reel grid with thumbnail ──────────────────────────────────────────
class _ReelGrid extends StatelessWidget {
  final List<ReelModel> reels;
  const _ReelGrid({required this.reels});

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) return const _EmptyState(
        icon: Icons.videocam_off_rounded, label: 'Ҳанӯз рил нест');

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 0.65),
      itemCount: reels.length,
      itemBuilder: (_, i) {
        final r       = reels[i];
        final thumbUrl = r.thumbnailUrl.isNotEmpty ? r.thumbnailUrl
            : r.videoUrl;
        return Stack(fit: StackFit.expand, children: [
          thumbUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.card),
                  errorWidget: (_, __, ___) => Container(color: AppColors.card))
              : Container(color: AppColors.card),
          // Gradient overlay
          Positioned(bottom: 0, left: 0, right: 0, height: 44,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
          const Positioned(top: 6, right: 6,
            child: Icon(Icons.play_circle_filled_rounded,
                color: Colors.white70, size: 17)),
          Positioned(bottom: 5, left: 5, child: Row(children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 2),
            Text('${_fmt(r.viewsCount ?? r.likesCount)}',
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ])),
        ]);
      });
  }

  String _fmt(int n) {
    if (n >= 1000000) { return '${(n/1e6).toStringAsFixed(1)}M'; }
    if (n >= 1000) { return '${(n/1000).toStringAsFixed(1)}K'; }
    return '$n';
  }
}

// ── Tagged grid ───────────────────────────────────────────────────────
class _TaggedGrid extends StatefulWidget {
  final String userId;
  final ProfileController ctrl;
  const _TaggedGrid({required this.userId, required this.ctrl});
  @override
  State<_TaggedGrid> createState() => _TaggedGridState();
}

class _TaggedGridState extends State<_TaggedGrid> {
  @override
  void initState() {
    super.initState();
    if (widget.ctrl.taggedPosts.isEmpty) { widget.ctrl.loadTaggedPosts(); }
    widget.ctrl.addListener(_refresh);
  }

  @override
  void dispose() { widget.ctrl.removeListener(_refresh); super.dispose(); }
  void _refresh() { if (mounted) { setState(() {}); } }

  @override
  Widget build(BuildContext context) {
    final posts = widget.ctrl.taggedPosts;
    if (posts.isEmpty) return const _EmptyState(
        icon: Icons.person_pin_outlined, label: 'Ҳанӯз зикр нашудааст');

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final url = posts[i].mediaUrl;
        return GestureDetector(
          onTap: () {},
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => Container(color: AppColors.card,
                child: const Icon(Icons.person_pin_outlined,
                    color: Colors.white24, size: 28))));
      });
  }
}

// ── Post sheet (full swipe view) ──────────────────────────────────────
class _PostSheet extends StatefulWidget {
  final List<PostModel> posts; final int idx;
  const _PostSheet({required this.posts, required this.idx});
  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  late final PageController _pg;
  @override void initState() { super.initState(); _pg = PageController(initialPage: widget.idx); }
  @override void dispose() { _pg.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.92,
    decoration: const BoxDecoration(color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      Container(margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
      Expanded(child: PageView.builder(
        controller: _pg,
        itemCount: widget.posts.length,
        itemBuilder: (_, i) {
          final p   = widget.posts[i];
          final url = p.mediaUrl;
          return SingleChildScrollView(child: Column(children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        Container(height: 300, color: AppColors.card),
                    errorWidget: (_, __, ___) =>
                        Container(height: 300, color: AppColors.card))
                : Container(height: 300, color: AppColors.card),
            if (p.caption.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text(p.caption, style: const TextStyle(
                      color: Colors.white, fontSize: 14)))),
            Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Row(children: [
                const Icon(Icons.favorite_border_rounded,
                    color: Colors.white54, size: 20),
                const SizedBox(width: 6),
                Text('p.likesCount',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text('p.commentsCount',
                    style: const TextStyle(color: Colors.white54)),
              ])),
          ]));
        })),
    ]));
}

// ── Animated empty state ──────────────────────────────────────────────
class _EmptyState extends StatefulWidget {
  final IconData icon; final String label;
  const _EmptyState({required this.icon, required this.label});
  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _scale = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      ScaleTransition(scale: _scale,
        child: Icon(widget.icon, size: 52, color: Colors.white12)),
      const SizedBox(height: 10),
      Text(widget.label,
          style: const TextStyle(color: Colors.white30, fontSize: 14)),
    ]));
}

// ── Followers / Following sheet ───────────────────────────────────────
class _UserListSheet extends StatefulWidget {
  final String title, userId; final bool isFollowers;
  const _UserListSheet({required this.title, required this.userId,
      required this.isFollowers});
  @override
  State<_UserListSheet> createState() => _UserListSheetState();
}

class _UserListSheetState extends State<_UserListSheet> {
  final _repo = ProfileRepository(ApiClient.instance);
  List<UserModel> _list    = [];
  bool            _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final list = widget.isFollowers
        ? await _repo.getFollowers(widget.userId)
        : await _repo.getFollowing(widget.userId);
    if (mounted) { setState(() { _list = list; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.65,
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      const SizedBox(height: 10),
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 14),
      Text(widget.title, style: const TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Divider(color: Colors.white10),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2))
          : _list.isEmpty
              ? Center(child: Text('Ҳанӯз ${widget.title.toLowerCase()} нест',
                  style: const TextStyle(color: Colors.white30, fontSize: 14)))
              : ListView.builder(
                  itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final u = _list[i];
                    return ListTile(
                      leading: CircleAvatar(radius: 22,
                        backgroundColor: AppColors.card,
                        backgroundImage: u.avatar.isNotEmpty
                            ? NetworkImage(u.avatar) : null,
                        child: u.avatar.isEmpty
                            ? const Icon(Icons.person, color: Colors.white38) : null),
                      title: Row(children: [
                        Text(u.username, style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                        if (u.verified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14)]]),
                      subtitle: (u.bio ?? '').isNotEmpty
                          ? Text(u.bio!, style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: u.id)));
                      });
                  })),
    ]));
}

// ── Verify sheet ──────────────────────────────────────────────────────
class _VerifySheet extends StatelessWidget {
  const _VerifySheet();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      Container(width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: const Color(0xFF00C853).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4), width: 2)),
        child: const Icon(Icons.verified_rounded,
            color: Color(0xFF00C853), size: 34)),
      const SizedBox(height: 16),
      const Text('Профили тасдиқшуда',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('\$2 / моҳ — Тасдиқ кун',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15)))),
    ]));
}
