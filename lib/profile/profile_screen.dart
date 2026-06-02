// lib/profile/profile_screen.dart
// Raonson Profile V2 — Part 1
// Header + Avatar Cropper + Stats + Highlights + Buttons + 4 Tabs
// NO Threads icon. Backend connected. Realtime.
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
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
import 'share_profile_sheet.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool   byUsername;
  const ProfileScreen(
      {super.key, required this.userId, this.byUsername = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileController _ctrl;
  late       TabController     _tab;

  bool get _isMe =>
      widget.userId == 'me' ||
      (UserSession.userId != null &&
          UserSession.userId == _ctrl.profile?.id);

  @override
  void initState() {
    super.initState();
    _ctrl = ProfileController(
        userId: widget.userId, byUsername: widget.byUsername);
    _ctrl.loadProfile();
    _tab = TabController(length: 3, vsync: this);
    _ctrl.addListener(_onCtrlUpdate);
  }

  void _onCtrlUpdate() {
    if (!mounted) return;
    // Rebuild tab controller if isMe changed (4th tab)
    final wantLen = _isMe ? 4 : 3;
    if (_tab.length != wantLen) {
      _tab.dispose();
      _tab = TabController(length: wantLen, vsync: this);
    }
    _tab.addListener(() {
      if (_tab.index == 2 && _ctrl.taggedPosts.isEmpty) {
        _ctrl.loadTaggedPosts();
      }
      if (_isMe && _tab.index == 3 && _ctrl.savedPosts.isEmpty) {
        _ctrl.loadSavedPosts();
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrlUpdate);
    _ctrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  // ── Avatar menu ──────────────────────────────────────────────────
  void _onAvatarTap() {
    if (!_isMe) { _viewFullPhoto(); return; }
    _showSheet([
      _item(Icons.person_rounded, 'Расмро бин',
          () { Navigator.pop(context); _viewFullPhoto(); }),
      _item(Icons.photo_library_rounded, 'Галерея',
          () { Navigator.pop(context); _pickAvatar(ImageSource.gallery); }),
      _item(Icons.camera_alt_rounded, 'Камера',
          () { Navigator.pop(context); _pickAvatar(ImageSource.camera); }),
      if ((_ctrl.profile?.avatar ?? '').isNotEmpty)
        _item(Icons.delete_outline_rounded, 'Расмро нест кун',
            () { Navigator.pop(context); _ctrl.removeAvatar(); },
            color: Colors.redAccent),
    ]);
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final xf = await ImagePicker()
        .pickImage(source: src, imageQuality: 92);
    if (xf == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: xf.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Расмро танзим кун',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.neonBlue,
          backgroundColor: Colors.black,
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x5,
            CropAspectRatioPreset.original,
          ],
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Расмро танзим кун',
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x5,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    await _ctrl.uploadAvatar(File(cropped.path));
  }

  void _viewFullPhoto() {
    final url = _ctrl.profile?.avatar ?? '';
    if (url.isEmpty) return;
    showDialog(context: context, barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(child: Hero(tag: 'av_${widget.userId}',
          child: ClipOval(child: CachedNetworkImage(
              imageUrl: url, width: 280, height: 280, fit: BoxFit.cover))))));
  }

  // ── Highlights long press ────────────────────────────────────────
  void _onHighlightLongPress(HighlightModel h) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HighlightOptionsSheet(
          highlight: h,
          onDelete:  () => _ctrl.deleteHighlight(h.id)));
  }

  // ── Other user menu ──────────────────────────────────────────────
  void _showOtherMenu() {
    final u = _ctrl.profile;
    if (u == null) return;
    _showSheet([
      _item(u.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
        u.isBlocked ? 'Блокро бардор' : '${u.username}-ро блок кун',
        () { Navigator.pop(context); _confirmBlock(u.isBlocked); },
        color: u.isBlocked ? Colors.greenAccent : Colors.redAccent),
      _item(Icons.flag_outlined, 'Шикоят кун',
        () { Navigator.pop(context); _snack('Шикоят фиристода шуд'); },
        color: Colors.orange),
      _item(Icons.link_rounded, 'Линкро нусха кун', () {
        Navigator.pop(context);
        Clipboard.setData(
            ClipboardData(text: 'https://raonson.app/${u.username}'));
        _snack('Линк нусхабардорӣ шуд');
      }),
    ]);
  }

  void _confirmBlock(bool current) {
    final u = _ctrl.profile!;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Text(current ? 'Блокро бардор?' : '${u.username}-ро блок кун?',
          style: const TextStyle(color: Colors.white)),
      content: Text(current
          ? '${u.username} барнома-и шуморо дида метавонад.'
          : '${u.username} шуморо дида наметавонад.',
          style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: () { Navigator.pop(context); _ctrl.toggleBlock(); },
            child: Text(current ? 'Бардор' : 'Блок кун',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  // ── Post long press ──────────────────────────────────────────────
  void _postMenu(PostModel post) {
    if (!_isMe) return;
    _showSheet([
      _item(post.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        post.isPinned ? 'Сабтро бардор' : 'Профилда сабт кун',
        () { Navigator.pop(context); _ctrl.togglePinPost(post); }),
      _item(Icons.delete_outline_rounded, 'Нест кун',
        () { Navigator.pop(context); _confirmDeletePost(post); },
        color: Colors.redAccent),
    ]);
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
        TextButton(onPressed: () { Navigator.pop(context); _ctrl.deletePost(post); },
            child: const Text('Нест кун',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  Future<void> _launchWeb(String url) async {
    final u = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareProfile() {
    final u = _ctrl.profile;
    if (u == null) return;
    showModalBottomSheet(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ShareProfileSheet(user: u));
  }

  void _verifySheet() => showModalBottomSheet(context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VerifySheet());

  String _mutualText(UserModel u) {
    if (u.mutualCount == 0) return '';
    if (u.mutualNames.isEmpty) return '${u.mutualCount} умумӣ пайрав';
    if (u.mutualCount == 1) return '${u.mutualNames.first} пайрав мешавад';
    if (u.mutualCount == 2)
      return '${u.mutualNames.first} ва ${u.mutualNames.last} пайрав мешаванд';
    return '${u.mutualNames.first}, ${u.mutualNames.last} ва '
        '${u.mutualCount - 2} нафари дигар';
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) return const ProfileSkeleton();

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
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP BAR ──────────────────────────────────────────
              SafeArea(bottom: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.maybePop(context))
                  else const SizedBox(width: 8),
                  Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(user.username,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                    if (user.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF00C853), size: 16),
                    ],
                  ])),
                  // Share
                  IconButton(icon: const Icon(Icons.share_outlined,
                      color: Colors.white, size: 20),
                      onPressed: _shareProfile),
                  // Menu (settings for own, more for other)
                  _isMe
                      ? IconButton(
                          icon: const Icon(Icons.more_horiz_rounded,
                              color: Colors.white, size: 22),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())))
                      : IconButton(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Colors.white, size: 22),
                          onPressed: _showOtherMenu),
                ]),
              )),

              // ── AVATAR + STATS ────────────────────────────────────
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Tappable avatar with Hero
                  GestureDetector(
                    onTap: _onAvatarTap,
                    child: Hero(tag: 'av_${widget.userId}',
                        child: _AvatarWidget(url: avatarUrl, size: 86))),
                  const SizedBox(width: 24),
                  Expanded(child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatWidget(count: user.postsCount,     label: 'Постҳо'),
                      _StatWidget(count: user.followersCount, label: 'Пайравон',
                          onTap: () => _userList('Пайравон', user.id, true)),
                      _StatWidget(count: user.followingCount, label: 'Пайравӣ',
                          onTap: () => _userList('Пайравӣ', user.id, false)),
                    ])),
                ])),

              // ── FULL NAME ─────────────────────────────────────────
              if ((user.fullName ?? '').isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(user.fullName!, style: const TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold))),

              // ── BIO ───────────────────────────────────────────────
              if ((user.bio ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16,
                      (user.fullName ?? '').isNotEmpty ? 4 : 12, 16, 0),
                  child: Text(user.bio!, style: const TextStyle(
                      color: Colors.white, fontSize: 13.5, height: 1.45))),

              // ── WEBSITE ───────────────────────────────────────────
              if ((user.website ?? '').isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                  child: GestureDetector(
                    onTap: () => _launchWeb(user.website!),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.link_rounded,
                          color: AppColors.neonBlue, size: 14),
                      const SizedBox(width: 5),
                      Text(user.website!, style: const TextStyle(
                          color: AppColors.neonBlue,
                          fontSize: 13.5, fontWeight: FontWeight.w500)),
                    ]))),

              // ── HIGHLIGHTS ────────────────────────────────────────
              const SizedBox(height: 12),
              HighlightsRow(
                highlights:  _ctrl.highlights,
                isMe:        _isMe,
                onAdd:       _isMe ? () {} : null,
                onLongPress: _isMe ? _onHighlightLongPress : null,
              ),

              // ── BUTTONS ───────────────────────────────────────────
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: _isMe
                    ? _OwnButtons(
                        onEdit: () async {
                          final ok = await Navigator.push<bool>(context,
                              MaterialPageRoute(builder: (_) =>
                                  EditProfileScreen(userId: widget.userId)));
                          if (ok == true && mounted) _ctrl.loadProfile();
                        },
                        onShare:  _shareProfile,
                        verified: user.verified,
                        onVerify: user.verified ? null : _verifySheet)
                    : _OtherButtons(
                        isFollowing:       user.isFollowing,
                        isPrivate:         user.isPrivate,
                        followRequestSent: user.followRequestSent,
                        onFollow:  _ctrl.toggleFollow,
                        onMessage: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => ChatRoomScreen(peer: user))))),

              // ── MUTUAL ────────────────────────────────────────────
              if (!_isMe && _mutualText(user).isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(children: [
                    const Icon(Icons.people_outline_rounded,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_mutualText(user),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12.5),
                        maxLines: 2)),
                  ])),

              // ── TAB BAR ───────────────────────────────────────────
              const SizedBox(height: 12),
              TabBar(
                controller: _tab,
                tabs: [
                  const Tab(icon: Icon(Icons.grid_on_rounded)),
                  const Tab(icon: Icon(Icons.slow_motion_video_rounded)),
                  const Tab(icon: Icon(Icons.person_pin_outlined)),
                  if (_isMe)
                    const Tab(icon: Icon(Icons.bookmark_border_rounded)),
                ],
                indicatorColor:       Colors.white,
                indicatorWeight:      2,
                indicatorSize:        TabBarIndicatorSize.tab,
                labelColor:           Colors.white,
                unselectedLabelColor: Colors.white24,
                dividerColor:         Colors.white10,
              ),
            ]))],
        body: TabBarView(controller: _tab, children: [
          _PostGrid(posts: _ctrl.sortedPosts, isMe: _isMe, onLongPress: _postMenu),
          _ReelGrid(reels: _ctrl.reels),
          _TaggedGrid(ctrl: _ctrl),
          if (_isMe) _SavedGrid(ctrl: _ctrl),
        ]),
      ),
    );
  }

  void _userList(String title, String uid, bool isFollowers) {
    showModalBottomSheet(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UserListSheet(
            title: title, userId: uid, isFollowers: isFollowers));
  }

  // helpers
  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  void _showSheet(List<Widget> items) => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [_handleBar(), ...items, const SizedBox(height: 8)])));

  Widget _handleBar() => Center(child: Container(
    width: 36, height: 4,
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
        color: Colors.white24, borderRadius: BorderRadius.circular(2))));

  Widget _item(IconData icon, String label, VoidCallback onTap,
      {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? Colors.white),
        title: Text(label, style: TextStyle(
            color: color ?? Colors.white, fontSize: 16)),
        onTap: onTap);
}

// ════════════════════════════════════════════════════════════════════
//  AVATAR WIDGET
// ════════════════════════════════════════════════════════════════════
class _AvatarWidget extends StatelessWidget {
  final String url; final double size;
  const _AvatarWidget({required this.url, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card,
        border: Border.all(color: Colors.white12, width: 1.5)),
    child: ClipOval(child: url.isNotEmpty
        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
            width: size, height: size,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => _icon(size))
        : _icon(size)));
  Widget _icon(double s) => Container(color: AppColors.card,
      child: Icon(Icons.person_rounded, color: Colors.white38, size: s * .5));
}

// ════════════════════════════════════════════════════════════════════
//  STAT WIDGET
// ════════════════════════════════════════════════════════════════════
class _StatWidget extends StatelessWidget {
  final int count; final String label; final VoidCallback? onTap;
  const _StatWidget({required this.count, required this.label, this.onTap});
  String _f(int n) {
    if (n >= 1000000) return '${(n/1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K';
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

// ════════════════════════════════════════════════════════════════════
//  OWN BUTTONS
// ════════════════════════════════════════════════════════════════════
class _OwnButtons extends StatelessWidget {
  final VoidCallback onEdit, onShare;
  final bool         verified;
  final VoidCallback? onVerify;
  const _OwnButtons({required this.onEdit, required this.onShare,
      required this.verified, this.onVerify});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _Btn(label: 'Таҳрири профил',
        icon: Icons.edit_rounded, onTap: onEdit)),
    const SizedBox(width: 8),
    Expanded(child: _Btn(label: 'Мубодила',
        icon: Icons.share_rounded, onTap: onShare)),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: verified ? null : onVerify,
      child: Container(height: 36, width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF00C853).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.5))),
        child: const Icon(Icons.verified_rounded,
            color: Color(0xFF00C853), size: 20))),
  ]);
}

// ════════════════════════════════════════════════════════════════════
//  OTHER USER BUTTONS
// ════════════════════════════════════════════════════════════════════
class _OtherButtons extends StatelessWidget {
  final bool isFollowing, isPrivate, followRequestSent;
  final VoidCallback onFollow, onMessage;
  const _OtherButtons({required this.isFollowing, required this.isPrivate,
      required this.followRequestSent, required this.onFollow,
      required this.onMessage});
  String get _label {
    if (isFollowing)       return 'Пайравишуда';
    if (followRequestSent) return 'Дархост фиристода шуд';
    return 'Пайравӣ';
  }
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: GestureDetector(
      onTap: followRequestSent ? null : onFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        decoration: BoxDecoration(
          color: (isFollowing || followRequestSent)
              ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: (isFollowing || followRequestSent)
              ? Border.all(color: Colors.white24) : null),
        child: Center(child: Text(_label, style: TextStyle(
          color: (isFollowing || followRequestSent) ? Colors.white54 : Colors.black,
          fontWeight: FontWeight.bold, fontSize: 13.5)))))),
    const SizedBox(width: 8),
    GestureDetector(onTap: onMessage,
      child: Container(height: 36, width: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: AppColors.surface, border: Border.all(color: Colors.white12)),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: Colors.white70, size: 18))),
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
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis)),
      ])));
}

// ════════════════════════════════════════════════════════════════════
//  POST GRID  — uniform 3-column, views counter, pin badge
// ════════════════════════════════════════════════════════════════════
class _PostGrid extends StatelessWidget {
  final List<PostModel>          posts;
  final bool                     isMe;
  final void Function(PostModel) onLongPress;
  const _PostGrid({required this.posts, required this.isMe,
      required this.onLongPress});

  String _f(int n) {
    if (n >= 1000000) return '${(n/1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const _Empty(icon: Icons.grid_off_rounded,
        label: 'Ҳанӯз пост нест');
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 1.0),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final p   = posts[i];
        final url = p.media.isNotEmpty ? (p.media.first['url'] ?? '') : '';
        return GestureDetector(
          onTap: () => showModalBottomSheet(context: context,
              isScrollControlled: true, backgroundColor: Colors.transparent,
              builder: (_) => _PostSheet(posts: posts, idx: i)),
          onLongPress: isMe ? () => onLongPress(p) : null,
          child: Stack(fit: StackFit.expand, children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(color: AppColors.card))
                : Container(color: AppColors.card,
                    child: const Icon(Icons.image_outlined,
                        color: Colors.white24, size: 28)),
            // Multi
            if (p.media.length > 1)
              const Positioned(top: 6, right: 6, child: Icon(
                  Icons.collections_rounded, color: Colors.white, size: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            // Pin
            if (p.isPinned)
              const Positioned(top: 6, left: 6, child: Icon(
                  Icons.push_pin_rounded, color: Colors.white, size: 15,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            // Views 👁
            Positioned(bottom: 5, left: 5, child: Row(
              mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.remove_red_eye_rounded,
                  color: Colors.white, size: 11,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              const SizedBox(width: 2),
              Text(_f(p.likesCount), style: const TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            ])),
          ]));
      });
  }
}

// ════════════════════════════════════════════════════════════════════
//  REEL GRID  — 9:16 aspect, views counter
// ════════════════════════════════════════════════════════════════════
class _ReelGrid extends StatelessWidget {
  final List<ReelModel> reels;
  const _ReelGrid({required this.reels});

  String _f(int n) {
    if (n >= 1000000) return '${(n/1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) return const _Empty(icon: Icons.videocam_off_rounded,
        label: 'Ҳанӯз рил нест');
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 0.65),
      itemCount: reels.length,
      itemBuilder: (_, i) {
        final r = reels[i];
        final thumb = r.thumbnailUrl.isNotEmpty ? r.thumbnailUrl : r.videoUrl;
        return Stack(fit: StackFit.expand, children: [
          thumb.isNotEmpty
              ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.card),
                  errorWidget: (_, __, ___) => Container(color: AppColors.card))
              : Container(color: AppColors.card),
          // Gradient
          Positioned(bottom: 0, left: 0, right: 0, height: 44,
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
          // Reel icon
          const Positioned(top: 6, right: 6, child: Icon(
              Icons.slow_motion_video_rounded, color: Colors.white, size: 16,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          // Views
          Positioned(bottom: 5, left: 5, child: Row(children: [
            const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 11,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
            const SizedBox(width: 3),
            Text(_f(r.viewsCount), style: const TextStyle(color: Colors.white,
                fontSize: 11, fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ])),
        ]);
      });
  }
}

// ════════════════════════════════════════════════════════════════════
//  TAGGED GRID
// ════════════════════════════════════════════════════════════════════
class _TaggedGrid extends StatefulWidget {
  final ProfileController ctrl;
  const _TaggedGrid({required this.ctrl});
  @override State<_TaggedGrid> createState() => _TaggedGridState();
}
class _TaggedGridState extends State<_TaggedGrid> {
  @override void initState() { super.initState(); widget.ctrl.addListener(_r); }
  @override void dispose()   { widget.ctrl.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final posts = widget.ctrl.taggedPosts;
    if (posts.isEmpty) return const _Empty(icon: Icons.person_pin_outlined,
        label: 'Ҳанӯз зикр нашудааст');
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 1.0),
      itemCount: posts.length,
      itemBuilder: (_, i) => CachedNetworkImage(imageUrl: posts[i].mediaUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.card),
          errorWidget: (_, __, ___) => Container(color: AppColors.card)));
  }
}

// ════════════════════════════════════════════════════════════════════
//  SAVED GRID
// ════════════════════════════════════════════════════════════════════
class _SavedGrid extends StatefulWidget {
  final ProfileController ctrl;
  const _SavedGrid({required this.ctrl});
  @override State<_SavedGrid> createState() => _SavedGridState();
}
class _SavedGridState extends State<_SavedGrid> {
  @override void initState() { super.initState(); widget.ctrl.addListener(_r); }
  @override void dispose()   { widget.ctrl.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final posts = widget.ctrl.savedPosts;
    if (posts.isEmpty) return const _Empty(icon: Icons.bookmark_border_rounded,
        label: 'Сохташудаҳо нест');
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 1.0),
      itemCount: posts.length,
      itemBuilder: (_, i) => CachedNetworkImage(imageUrl: posts[i].mediaUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.card),
          errorWidget: (_, __, ___) => Container(color: AppColors.card)));
  }
}

// ════════════════════════════════════════════════════════════════════
//  POST SHEET
// ════════════════════════════════════════════════════════════════════
class _PostSheet extends StatefulWidget {
  final List<PostModel> posts; final int idx;
  const _PostSheet({required this.posts, required this.idx});
  @override State<_PostSheet> createState() => _PostSheetState();
}
class _PostSheetState extends State<_PostSheet> {
  late final PageController _pg;
  @override void initState() { super.initState(); _pg = PageController(initialPage: widget.idx); }
  @override void dispose()   { _pg.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.92,
    decoration: const BoxDecoration(color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      _bar(),
      Expanded(child: PageView.builder(
        controller: _pg, itemCount: widget.posts.length,
        itemBuilder: (_, i) {
          final p = widget.posts[i]; final url = p.mediaUrl;
          return SingleChildScrollView(child: Column(children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, width: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Container(height: 300, color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(height: 300, color: AppColors.card))
                : Container(height: 300, color: AppColors.card),
            if (p.caption.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text(p.caption, style: const TextStyle(color: Colors.white, fontSize: 14)))),
            Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              child: Row(children: [
                const Icon(Icons.favorite_border_rounded, color: Colors.white54, size: 20),
                const SizedBox(width: 6),
                Text('${p.likesCount}', style: const TextStyle(color: Colors.white54)),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text('${p.commentsCount}', style: const TextStyle(color: Colors.white54)),
              ])),
          ]));
        })),
    ]));
  Widget _bar() => Center(child: Container(width: 36, height: 4,
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))));
}

// ════════════════════════════════════════════════════════════════════
//  USER LIST SHEET
// ════════════════════════════════════════════════════════════════════
class _UserListSheet extends StatefulWidget {
  final String title, userId; final bool isFollowers;
  const _UserListSheet({required this.title, required this.userId,
      required this.isFollowers});
  @override State<_UserListSheet> createState() => _UserListSheetState();
}
class _UserListSheetState extends State<_UserListSheet> {
  final _repo = ProfileRepository(ApiClient.instance);
  List<UserModel> _list = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final list = widget.isFollowers
        ? await _repo.getFollowers(widget.userId)
        : await _repo.getFollowing(widget.userId);
    if (mounted) setState(() { _list = list; _loading = false; });
  }
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.65,
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      Center(child: Container(width: 36, height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Divider(color: Colors.white10),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2))
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
                      if (u.verified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 14)],
                    ]),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: u.id)));
                    });
                })),
    ]));
}

// ════════════════════════════════════════════════════════════════════
//  VERIFY SHEET
// ════════════════════════════════════════════════════════════════════
class _VerifySheet extends StatelessWidget {
  const _VerifySheet();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 12),
      Container(width: 72, height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: const Color(0xFF00C853).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4), width: 2)),
        child: const Icon(Icons.verified_rounded, color: Color(0xFF00C853), size: 36)),
      const SizedBox(height: 16),
      const Text('Raonson Verified', style: TextStyle(color: Colors.white,
          fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Профили тасдиқшуда корбаронро нишон медиҳад, ки шумо аслӣ ҳастед.',
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13.5),
          textAlign: TextAlign.center),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text('Тасдиқ дархост кун',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
      const SizedBox(height: 10),
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Бекор', style: TextStyle(color: Colors.white38))),
    ])));
}

// ════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ════════════════════════════════════════════════════════════════════
class _Empty extends StatefulWidget {
  final IconData icon; final String label;
  const _Empty({required this.icon, required this.label});
  @override State<_Empty> createState() => _EmptyState();
}
class _EmptyState extends State<_Empty> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _s = Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    ScaleTransition(scale: _s, child: Icon(widget.icon, size: 52, color: Colors.white12)),
    const SizedBox(height: 10),
    Text(widget.label, style: const TextStyle(color: Colors.white30, fontSize: 14)),
  ]));
}
