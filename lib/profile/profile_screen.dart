import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../settings/settings_screen.dart';
import 'profile_repository.dart';

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
  void dispose() { _ctrl.dispose(); _tab.dispose(); super.dispose(); }

  bool get _isMe =>
      widget.userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == _ctrl.profile?.id);

  void _share() {
    final u = _ctrl.profile;
    if (u == null) return;
    Clipboard.setData(ClipboardData(text: 'raonson://profile/${u.username}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Профил нусхабардорӣ шуд'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(
            color: AppColors.storyStart, strokeWidth: 2)));
    }
    final user = _ctrl.profile;
    if (user == null) {
      return Scaffold(backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0,
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
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP BAR
            SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                if (Navigator.canPop(context))
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context))
                else const SizedBox(width: 4),
                Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(user.username,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
                  if (user.verified) ...[const SizedBox(width: 5),
                    const Icon(Icons.verified_rounded, color: Color(0xFF00C853), size: 16)],
                ])),
                IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                    onPressed: _share),
                if (_isMe) IconButton(icon: const Icon(Icons.more_horiz_rounded,
                    color: Colors.white, size: 22),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              ]),
            )),

            // AVATAR + STATS
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

            // BIO
            if (user.bio != null && user.bio!.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(user.bio!, style: const TextStyle(
                    color: Colors.white, fontSize: 13.5, height: 1.4))),

            // BUTTONS
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: _isMe
                  ? _OwnBtns(
                      onEdit: () async {
                        final ok = await Navigator.push<bool>(context,
                            MaterialPageRoute(builder: (_) =>
                                EditProfileScreen(userId: widget.userId)));
                        if (ok == true && mounted) _ctrl.loadProfile();
                      },
                      onShare: _share,
                      onVerify: !user.verified ? _verifySheet : null)
                  : _OtherBtns(
                      isFollowing: user.isFollowing,
                      onFollow:    _ctrl.toggleFollow,
                      onMessage:   () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: user))))),

            // TABS
            const SizedBox(height: 8),
            TabBar(controller: _tab,
              tabs: const [Tab(icon: Icon(Icons.grid_on_rounded)),
                Tab(icon: Icon(Icons.play_circle_outline_rounded))],
              indicatorColor: Colors.white, indicatorWeight: 2,
              labelColor: Colors.white, unselectedLabelColor: Colors.white24,
              dividerColor: Colors.white10),
          ]))],
        body: TabBarView(controller: _tab, children: [
          _PostGrid(posts: _ctrl.posts),
          _ReelGrid(reels: _ctrl.reels),
        ]),
      ),
    );
  }

  void _showList(String title, String uid, bool followers) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserListSheet(title: title, userId: uid, isFollowers: followers));
  }

  void _verifySheet() => showModalBottomSheet(context: context,
    backgroundColor: Colors.transparent, builder: (_) => const _VerifySheet());
}

class _AvatarW extends StatelessWidget {
  final String url; final double size;
  const _AvatarW({required this.url, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card,
        border: Border.all(color: Colors.white12)),
    child: ClipOval(child: url.isNotEmpty
        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: size, height: size,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => Container(color: AppColors.card,
                child: Icon(Icons.person_rounded, color: Colors.white38, size: size*.5)))
        : Container(color: AppColors.card,
            child: Icon(Icons.person_rounded, color: Colors.white38, size: size*.5))));
}

class _Stat extends StatelessWidget {
  final int count; final String label; final VoidCallback? onTap;
  const _Stat({required this.count, required this.label, this.onTap});
  String _f(int n) { if (n>=1000000) return '${(n/1e6).toStringAsFixed(1)}M'; if (n>=1000) return '${(n/1000).toStringAsFixed(1)}K'; return '$n'; }
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Column(children: [
      Text(_f(count), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11.5))]));
}

class _OwnBtns extends StatelessWidget {
  final VoidCallback onEdit, onShare; final VoidCallback? onVerify;
  const _OwnBtns({required this.onEdit, required this.onShare, this.onVerify});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _Btn(label: 'Таҳрири профил', icon: Icons.edit_rounded, onTap: onEdit)),
    const SizedBox(width: 8),
    Expanded(child: _Btn(label: 'Мубодила', icon: Icons.share_rounded, onTap: onShare)),
    if (onVerify != null) ...[const SizedBox(width: 8),
      GestureDetector(onTap: onVerify, child: Container(height: 36, width: 36,
        decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.5))),
        child: const Icon(Icons.verified_rounded, color: Color(0xFF00C853), size: 20)))],
  ]);
}

class _OtherBtns extends StatelessWidget {
  final bool isFollowing; final VoidCallback onFollow, onMessage;
  const _OtherBtns({required this.isFollowing, required this.onFollow, required this.onMessage});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: GestureDetector(onTap: onFollow,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), height: 36,
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isFollowing ? Border.all(color: Colors.white24) : null),
        child: Center(child: Text(isFollowing ? 'Пайравишуда' : 'Пайравӣ',
          style: TextStyle(color: isFollowing ? Colors.white54 : Colors.black,
              fontWeight: FontWeight.bold, fontSize: 14)))))),
    const SizedBox(width: 8),
    GestureDetector(onTap: onMessage, child: Container(height: 36, width: 36,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
        color: AppColors.surface, border: Border.all(color: Colors.white12)),
      child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 18))),
  ]);
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(height: 36,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
        color: AppColors.surface, border: Border.all(color: Colors.white12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 15), const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis))])));
}

class _PostGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _PostGrid({required this.posts});
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.grid_off_rounded, size: 52, color: Colors.white12), SizedBox(height: 10),
      Text('Ҳанӯз пост нест', style: TextStyle(color: Colors.white30, fontSize: 14))]));
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final url = posts[i].media.isNotEmpty ? (posts[i].media.first['url'] ?? '') : '';
        return GestureDetector(
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _PostSheet(posts: posts, idx: i)),
          child: Stack(fit: StackFit.expand, children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(color: AppColors.card))
                : Container(color: AppColors.card,
                    child: const Icon(Icons.image_outlined, color: Colors.white24, size: 28)),
            if (posts[i].media.length > 1)
              const Positioned(top: 6, right: 6,
                child: Icon(Icons.collections_rounded, color: Colors.white, size: 16,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ]));
      });
  }
}

class _PostSheet extends StatefulWidget {
  final List<PostModel> posts; final int idx;
  const _PostSheet({required this.posts, required this.idx});
  @override State<_PostSheet> createState() => _PostSheetState();
}
class _PostSheetState extends State<_PostSheet> {
  late final PageController _pg;
  @override void initState() { super.initState(); _pg = PageController(initialPage: widget.idx); }
  @override void dispose() { _pg.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.92,
    decoration: const BoxDecoration(color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
      Expanded(child: PageView.builder(controller: _pg, itemCount: widget.posts.length,
        itemBuilder: (_, i) {
          final p = widget.posts[i];
          final url = p.media.isNotEmpty ? (p.media.first['url'] ?? '') : '';
          return SingleChildScrollView(child: Column(children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, width: double.infinity, fit: BoxFit.contain,
                    placeholder: (_, __) => Container(height: 300, color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(height: 300, color: AppColors.card))
                : Container(height: 300, color: AppColors.card),
            if (p.caption.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(14,10,14,0),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text(p.caption, style: const TextStyle(color: Colors.white, fontSize: 14)))),
            Padding(padding: const EdgeInsets.fromLTRB(14,8,14,16),
              child: Row(children: [
                const Icon(Icons.favorite_border_rounded, color: Colors.white54, size: 20),
                const SizedBox(width: 6), Text('${p.likesCount}', style: const TextStyle(color: Colors.white54)),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 6), Text('${p.commentsCount}', style: const TextStyle(color: Colors.white54)),
              ])),
          ]));
        })),
    ]));
}

class _ReelGrid extends StatelessWidget {
  final List<ReelModel> reels;
  const _ReelGrid({required this.reels});
  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.videocam_off_rounded, size: 52, color: Colors.white12), SizedBox(height: 10),
      Text('Ҳанӯз рил нест', style: TextStyle(color: Colors.white30, fontSize: 14))]));
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 0.7),
      itemCount: reels.length,
      itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
        Container(color: AppColors.card),
        const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 32)),
        Positioned(bottom: 6, left: 6, child: Row(children: [
          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
          const SizedBox(width: 2),
          Text('${reels[i].likesCount}', style: const TextStyle(color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
        ])),
      ]));
  }
}

class _UserListSheet extends StatefulWidget {
  final String title, userId; final bool isFollowers;
  const _UserListSheet({required this.title, required this.userId, required this.isFollowers});
  @override State<_UserListSheet> createState() => _UserListSheetState();
}
class _UserListSheetState extends State<_UserListSheet> {
  final _repo = ProfileRepository(ApiClient.instance);
  List<UserModel> _list = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final list = widget.isFollowers ? await _repo.getFollowers(widget.userId) : await _repo.getFollowing(widget.userId);
    if (mounted) setState(() { _list = list; _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.65,
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      const SizedBox(height: 10),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 14),
      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Divider(color: Colors.white10),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.storyStart, strokeWidth: 2))
          : _list.isEmpty
              ? Center(child: Text('Ҳанӯз ${widget.title.toLowerCase()} нест',
                  style: const TextStyle(color: Colors.white30, fontSize: 14)))
              : ListView.builder(itemCount: _list.length, itemBuilder: (_, i) {
                  final u = _list[i];
                  return ListTile(
                    leading: CircleAvatar(radius: 22, backgroundColor: AppColors.card,
                      backgroundImage: u.avatar.isNotEmpty ? NetworkImage(u.avatar) : null,
                      child: u.avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38) : null),
                    title: Row(children: [
                      Text(u.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      if (u.verified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 14)]]),
                    subtitle: u.bio != null && u.bio!.isNotEmpty
                        ? Text(u.bio!, style: const TextStyle(color: Colors.white38, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                    onTap: () { Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: u.id))); });
                })),
    ]));
}

class _VerifySheet extends StatelessWidget {
  const _VerifySheet();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      Container(width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00C853).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4), width: 2)),
        child: const Icon(Icons.verified_rounded, color: Color(0xFF00C853), size: 34)),
      const SizedBox(height: 16),
      const Text('Профили тасдиқшуда', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text('\$2 / моҳ — Тасдиқ кун',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
    ]));
}
