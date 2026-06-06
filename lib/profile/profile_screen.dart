// lib/profile/profile_screen.dart — Part 1 FIXED

// NO qr_flutter. Share via share_plus.
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../create/upload/upload_manager.dart';
import '../feed/post/post_detail_screen.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import '../widgets/verified_badge.dart';
import 'edit/edit_profile_screen.dart';
import 'highlight_model.dart';
import 'highlights_row.dart';
import 'profile_controller.dart';
import 'profile_repository.dart';
import 'profile_skeleton.dart';
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
    with TickerProviderStateMixin {
  late final ProfileController _ctrl;
  late       TabController      _tab;

  bool get _isMe =>
      widget.userId == 'me' ||
      (UserSession.userId != null &&
          UserSession.userId == _ctrl.profile?.id);

  @override
  void initState() {
    super.initState();
    _ctrl = ProfileController(
        userId: widget.userId, byUsername: widget.byUsername);
    _tab  = TabController(length: 3, vsync: this);
    _ctrl.loadProfile();
    _ctrl.addListener(_onCtrl);
  }

  void _onCtrl() {
    if (!mounted) return;
    final want = _isMe ? 4 : 3;
    if (_tab.length != want) {
      final old = _tab;
      _tab = TabController(length: want, vsync: this);
      _tab.addListener(_tabChanged);
      old.dispose();
    }
    setState(() {});
  }

  void _tabChanged() {
    if (!mounted) return;
    if (_tab.index == 2 && _ctrl.taggedPosts.isEmpty) {
      _ctrl.loadTaggedPosts();
    }
    if (_isMe && _tab.index == 3 && _ctrl.savedPosts.isEmpty) {
      _ctrl.loadSavedPosts();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    _ctrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  // ── Avatar ────────────────────────────────────────────────────────
  void _avatarTap() {
    if (!_isMe) { _viewPhoto(); return; }
    _sheet([
      _tile(Icons.person_rounded, 'Расмро бин',
          () { Navigator.pop(context); _viewPhoto(); }),
      _tile(Icons.photo_library_rounded, 'Галерея',
          () { Navigator.pop(context); _pick(ImageSource.gallery); }),
      _tile(Icons.camera_alt_rounded, 'Камера',
          () { Navigator.pop(context); _pick(ImageSource.camera); }),
      if ((_ctrl.profile?.avatar ?? '').isNotEmpty)
        _tile(Icons.delete_outline_rounded, 'Расмро нест кун',
            () { Navigator.pop(context); _ctrl.removeAvatar(); },
            red: true),
    ]);
  }

  Future<void> _pick(ImageSource src) async {
    final xf = await ImagePicker()
        .pickImage(source: src, imageQuality: 88, maxWidth: 800);
    if (xf == null || !mounted) return;
    await _ctrl.uploadAvatar(File(xf.path));
  }

  void _viewPhoto() {
    final url = _ctrl.profile?.avatar ?? '';
    if (url.isEmpty) return;
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(child: Hero(
          tag: 'av_${widget.userId}',
          child: ClipOval(child: CachedNetworkImage(
              imageUrl: url, width: 280, height: 280, fit: BoxFit.cover))))));
  }

  // ── Highlight long press ─────────────────────────────────────────
  void _hlLongPress(HighlightModel h) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => HighlightOptionsSheet(
          highlight: h, onDelete: () => _ctrl.deleteHighlight(h.id)));
  }

  // ── Create highlight (Актуальный) ────────────────────────────────
  Future<void> _createHighlight() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    final title = await _askHighlightTitle();
    if (title == null || title.trim().isEmpty || !mounted) return;

    // Loading overlay
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2)),
    );
    String coverUrl = '';
    try {
      coverUrl = await UploadManager().uploadFile(File(picked.path));
    } catch (_) {}
    await _ctrl.createHighlight(title.trim(), coverUrl, const []);
    if (mounted) Navigator.pop(context); // close loading
  }

  Future<String?> _askHighlightTitle() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Актуальни нав',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ном...',
            hintStyle: TextStyle(color: Colors.white38),
            counterStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.neonBlue)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Бекор',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Эҷод',
                  style: TextStyle(
                      color: AppColors.neonBlue, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ── Other user menu ───────────────────────────────────────────────
  void _otherMenu() {
    final u = _ctrl.profile; if (u == null) return;
    _sheet([
      _tile(u.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
          u.isBlocked ? 'Блокро бардор' : '${u.username}-ро блок кун',
          () { Navigator.pop(context); _confirmBlock(u.isBlocked); },
          red: !u.isBlocked),
      _tile(Icons.flag_outlined, 'Шикоят кун',
          () { Navigator.pop(context); _snack('Шикоят фиристода шуд'); }),
      _tile(Icons.link_rounded, 'Линкро нусха кун', () {
        Navigator.pop(context);
        Clipboard.setData(
            ClipboardData(text: 'https://raonson.app/${u.username}'));
        _snack('Линк нусхабардорӣ шуд');
      }),
    ]);
  }

  void _confirmBlock(bool cur) {
    final u = _ctrl.profile!;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Text(cur ? 'Блокро бардор?' : '${u.username}-ро блок кун?',
          style: const TextStyle(color: Colors.white)),
      content: Text(cur
          ? '${u.username} барнома-и шуморо дида метавонад.'
          : '${u.username} шуморо дида наметавонад.',
          style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: () { Navigator.pop(context); _ctrl.toggleBlock(); },
            child: Text(cur ? 'Бардор' : 'Блок кун',
                style: const TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold))),
      ]));
  }

  void _postMenu(PostModel p) {
    if (!_isMe) return;
    _sheet([
      _tile(p.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          p.isPinned ? 'Сабтро бардор' : 'Профилда сабт кун',
          () { Navigator.pop(context); _ctrl.togglePinPost(p); }),
      _tile(Icons.delete_outline_rounded, 'Нест кун',
          () { Navigator.pop(context); _confirmDelete(p); }, red: true),
    ]);
  }

  void _confirmDelete(PostModel p) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text('Нест кардан?',
          style: TextStyle(color: Colors.white)),
      content: const Text('Ин пост тамоман нест мешавад.',
          style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: () { Navigator.pop(context); _ctrl.deletePost(p); },
            child: const Text('Нест кун',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold))),
      ]));
  }

  Future<void> _launchWeb(String url) async {
    final u   = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareProfile() {
    final u = _ctrl.profile; if (u == null) return;
    showModalBottomSheet(context: context,
        isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => ShareProfileSheet(user: u));
  }

  void _verifySheet() => showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => const _VerifySheet());

  String _mutualTxt(UserModel u) {
    if (u.mutualCount == 0) return '';
    if (u.mutualNames.isEmpty) return '${u.mutualCount} умумӣ пайрав';
    if (u.mutualCount == 1) return '${u.mutualNames.first} пайрав мешавад';
    if (u.mutualCount == 2) {
      return '${u.mutualNames.first} ва ${u.mutualNames.last} пайрав мешаванд';
    }
    return '${u.mutualNames.first}, ${u.mutualNames.last} ва '
        '${u.mutualCount - 2} нафари дигар';
  }

  // ── BUILD ─────────────────────────────────────────────────────────
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
              child: const Text('Дубора',
                  style: TextStyle(color: AppColors.neonBlue))),
        ])));
    }

    final avatarUrl = user.avatar.isNotEmpty
        ? user.avatar : (_isMe ? (UserSession.avatar ?? '') : '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        color: AppColors.neonBlue,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await _ctrl.loadProfile();
          if (_tab.index == 2) await _ctrl.loadTaggedPosts();
          if (_isMe && _tab.index == 3) await _ctrl.loadSavedPosts();
        },
        child: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── TOP BAR ────────────────────────────────────────────
              SafeArea(bottom: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.maybePop(context))
                  else
                    const SizedBox(width: 8),
                  Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(user.username,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                    if (user.isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF00C853), size: 16),
                    ],
                  ])),
                  IconButton(icon: const Icon(Icons.share_outlined,
                      color: Colors.white, size: 20),
                      onPressed: _shareProfile),
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
                          onPressed: _otherMenu),
                ]),
              )),

              // ── AVATAR + STATS ──────────────────────────────────────
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(onTap: _avatarTap,
                      child: Hero(tag: 'av_${widget.userId}',
                          child: _Avatar(url: avatarUrl, size: 86))),
                    const SizedBox(width: 24),
                    Expanded(child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(n: user.postsCount,     label: 'Постҳо'),
                        _Stat(n: user.followersCount, label: 'Пайравон',
                            onTap: () => _userList('Пайравон', user.id, true)),
                        _Stat(n: user.followingCount, label: 'Пайравӣ',
                            onTap: () => _userList('Пайравӣ', user.id, false)),
                      ])),
                  ])),

              // ── FULL NAME ───────────────────────────────────────────
              if ((user.fullName ?? '').isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(user.fullName!, style: const TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold))),

              // ── BIO ─────────────────────────────────────────────────
              if ((user.bio ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16,
                      (user.fullName ?? '').isNotEmpty ? 4 : 12, 16, 0),
                  child: Text(user.bio!, style: const TextStyle(
                      color: Colors.white, fontSize: 13.5, height: 1.45))),

              // ── WEBSITE ─────────────────────────────────────────────
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

              // ── HIGHLIGHTS ──────────────────────────────────────────
              const SizedBox(height: 12),
              HighlightsRow(
                highlights:  _ctrl.highlights,
                isMe:        _isMe,
                onAdd:       _isMe ? _createHighlight : null,
                onLongPress: _isMe ? _hlLongPress : null,
              ),

              // ── BUTTONS ─────────────────────────────────────────────
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: _isMe
                    ? _OwnBtns(
                        onEdit: () async {
                          final ok = await Navigator.push<bool>(context,
                              MaterialPageRoute(builder: (_) =>
                                  EditProfileScreen(userId: widget.userId)));
                          if (ok == true && mounted) {
                            _ctrl.loadProfile();
                          }
                        },
                        onShare:  _shareProfile,
                        verified: user.isVerified,
                        onVerify: user.isVerified ? null : _verifySheet)
                    : _OtherBtns(
                        isFollowing:       user.isFollowing,
                        isPrivate:         user.isPrivate,
                        followRequestSent: user.followRequestSent,
                        onFollow:  _ctrl.toggleFollow,
                        onMessage: () {})),

              // ── MUTUAL ──────────────────────────────────────────────
              if (!_isMe && _mutualTxt(user).isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(children: [
                    const Icon(Icons.people_outline_rounded,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_mutualTxt(user),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12.5),
                        maxLines: 2)),
                  ])),

              // ── TAB BAR ─────────────────────────────────────────────
              const SizedBox(height: 12),
              TabBar(
                controller: _tab,
                tabs: [
                  const Tab(icon: Icon(Icons.grid_on_rounded)),
                  Tab(icon: AnimatedBuilder(
                    animation: _tab,
                    builder: (_, __) => SvgPicture.asset(
                        'assets/icons/nav_reels.svg',
                        width: 22, height: 22,
                        colorFilter: ColorFilter.mode(
                            _tab.index == 1 ? Colors.white : Colors.white24,
                            BlendMode.srcIn)),
                  )),
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
          _PostGrid(
              posts:       _ctrl.sortedPosts,
              isMe:        _isMe,
              owner:       _ctrl.profile,
              onLongPress: _postMenu,
              onRemoved:   (id) => _ctrl.removePostById(id)),
          _ReelGrid(reels: _ctrl.reels),
          _TaggedGrid(ctrl: _ctrl),
          if (_isMe) _SavedGrid(ctrl: _ctrl),
        ]),
        ),
      ),
    );
  }

  void _userList(String title, String uid, bool isFollowers) {
    showModalBottomSheet(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UserListSheet(
            title: title, userId: uid, isFollowers: isFollowers));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  void _sheet(List<Widget> items) => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_bar(), ...items, const SizedBox(height: 8)])));

  Widget _bar() => Center(child: Container(width: 36, height: 4,
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: Colors.white24,
        borderRadius: BorderRadius.circular(2))));

  Widget _tile(IconData icon, String label, VoidCallback onTap,
      {bool red = false}) =>
      ListTile(
        leading: Icon(icon, color: red ? Colors.redAccent : Colors.white),
        title: Text(label, style: TextStyle(
            color: red ? Colors.redAccent : Colors.white, fontSize: 16)),
        onTap: onTap);
}

// ─── Avatar ────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String url; final double size;
  const _Avatar({required this.url, required this.size});
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
      child: Icon(Icons.person_rounded, color: Colors.white38, size: s*.5));
}

// ─── Stat ──────────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  final int n; final String label; final VoidCallback? onTap;
  const _Stat({required this.n, required this.label, this.onTap});
  String _f(int v) {
    if (v >= 1000000) return '${(v/1e6).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v/1000).toStringAsFixed(1)}K';
    return '$v';
  }
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Column(children: [
      Text(_f(n), style: const TextStyle(color: Colors.white,
          fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
    ]));
}

// ─── Own Buttons ────────────────────────────────────────────────────────
class _OwnBtns extends StatelessWidget {
  final VoidCallback onEdit, onShare;
  final bool verified;
  final VoidCallback? onVerify;
  const _OwnBtns({required this.onEdit, required this.onShare,
      required this.verified, this.onVerify});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _Btn(label: 'Таҳрири профил',
        icon: Icons.edit_rounded, onTap: onEdit)),
    const SizedBox(width: 8),
    Expanded(child: _Btn(label: 'Мубодила',
        icon: Icons.share_rounded, onTap: onShare)),
    const SizedBox(width: 8),
    GestureDetector(onTap: verified ? null : onVerify,
      child: Container(height: 36, width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF00C853).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF00C853).withOpacity(0.5))),
        child: const Icon(Icons.verified_rounded,
            color: Color(0xFF00C853), size: 20))),
  ]);
}

// ─── Other Buttons ──────────────────────────────────────────────────────
class _OtherBtns extends StatelessWidget {
  final bool isFollowing, isPrivate, followRequestSent;
  final VoidCallback onFollow, onMessage;
  const _OtherBtns({required this.isFollowing, required this.isPrivate,
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
          color: (isFollowing || followRequestSent)
              ? Colors.white54 : Colors.black,
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

// ─── Post Grid ─────────────────────────────────────────────────────────
class _PostGrid extends StatelessWidget {
  final List<PostModel> posts;
  final bool isMe;
  final UserModel? owner;
  final void Function(PostModel) onLongPress;
  final void Function(String id)? onRemoved;
  const _PostGrid({required this.posts, required this.isMe,
      required this.onLongPress, this.owner, this.onRemoved});
  String _f(int v) {
    if (v >= 1000000) return '${(v/1e6).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v/1000).toStringAsFixed(1)}K';
    return '$v';
  }
  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _Empty(icon: Icons.grid_off_rounded, label: 'Ҳанӯз пост нест');
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 1.0),
      itemCount: posts.length,
      itemBuilder: (ctx, i) {
        final p   = posts[i];
        final url = p.media.isNotEmpty ? (p.media.first['url'] ?? '') : '';
        return GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                  posts: posts, initialIndex: i, title: 'Постҳо',
                  fallbackUser: owner,
                  onPostDeleted: (post) => onRemoved?.call(post.id)))),
          onLongPress: isMe ? () => onLongPress(p) : null,
          child: Stack(fit: StackFit.expand, children: [
            url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(color: AppColors.card))
                : Container(color: AppColors.card,
                    child: const Icon(Icons.image_outlined,
                        color: Colors.white24, size: 28)),
            if (p.media.length > 1)
              const Positioned(top: 6, right: 6, child: Icon(
                  Icons.collections_rounded, color: Colors.white, size: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            if (p.isPinned)
              const Positioned(top: 6, left: 6, child: Icon(
                  Icons.push_pin_rounded, color: Colors.white, size: 15,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            Positioned(bottom: 5, left: 5,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.remove_red_eye_rounded,
                    color: Colors.white, size: 11,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                const SizedBox(width: 2),
                Text(_f(p.likesCount), style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
              ])),
          ]));
      });
  }
}

// ─── Reel Grid ─────────────────────────────────────────────────────────
class _ReelGrid extends StatelessWidget {
  final List<ReelModel> reels;
  const _ReelGrid({required this.reels});
  String _f(int v) {
    if (v >= 1000000) return '${(v/1e6).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v/1000).toStringAsFixed(1)}K';
    return '$v';
  }
  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return const _Empty(icon: Icons.videocam_off_rounded,
          label: 'Ҳанӯз рил нест');
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 0.65),
      itemCount: reels.length,
      itemBuilder: (_, i) {
        final r     = reels[i];
        final thumb = r.thumbnailUrl.isNotEmpty ? r.thumbnailUrl : r.videoUrl;
        return Stack(fit: StackFit.expand, children: [
          thumb.isNotEmpty
              ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.card),
                  errorWidget: (_, __, ___) => Container(color: AppColors.card))
              : Container(color: AppColors.card),
          Positioned(bottom: 0, left: 0, right: 0, height: 44,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
          Positioned(top: 6, right: 6, child: SvgPicture.asset(
              'assets/icons/nav_reels.svg', width: 16, height: 16,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
          Positioned(bottom: 5, left: 5,
            child: Row(children: [
              const Icon(Icons.remove_red_eye_rounded, color: Colors.white,
                  size: 11, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              const SizedBox(width: 3),
              Text(_f(r.viewsCount), style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            ])),
        ]);
      });
  }
}

// ─── Tagged Grid ────────────────────────────────────────────────────────
class _TaggedGrid extends StatefulWidget {
  final ProfileController ctrl;
  const _TaggedGrid({required this.ctrl});
  @override State<_TaggedGrid> createState() => _TGS();
}
class _TGS extends State<_TaggedGrid> {
  @override void initState() { super.initState(); widget.ctrl.addListener(_r); }
  @override void dispose()   { widget.ctrl.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final posts = widget.ctrl.taggedPosts;
    if (posts.isEmpty) {
      return const _Empty(icon: Icons.person_pin_outlined,
          label: 'Ҳанӯз зикр нашудааст');
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 1.0),
      itemCount: posts.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => PostDetailScreen(
                posts: posts, initialIndex: i, title: 'Зикршуда'))),
        child: CachedNetworkImage(
            imageUrl: posts[i].mediaUrl, fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => Container(color: AppColors.card))));
  }
}

// ─── Saved Grid ─────────────────────────────────────────────────────────
class _SavedGrid extends StatefulWidget {
  final ProfileController ctrl;
  const _SavedGrid({required this.ctrl});
  @override State<_SavedGrid> createState() => _SGS();
}
class _SGS extends State<_SavedGrid> {
  @override void initState() { super.initState(); widget.ctrl.addListener(_r); }
  @override void dispose()   { widget.ctrl.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final posts = widget.ctrl.savedPosts;
    if (posts.isEmpty) {
      return const _Empty(icon: Icons.bookmark_border_rounded,
          label: 'Сохташудаҳо нест');
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 1.0),
      itemCount: posts.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => PostDetailScreen(
                posts: posts, initialIndex: i, title: 'Сохташуда'))),
        child: CachedNetworkImage(
            imageUrl: posts[i].mediaUrl, fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => Container(color: AppColors.card))));
  }
}

// ─── User List Sheet ────────────────────────────────────────────────────
class _UserListSheet extends StatefulWidget {
  final String title, userId; final bool isFollowers;
  const _UserListSheet({required this.title, required this.userId,
      required this.isFollowers});
  @override State<_UserListSheet> createState() => _ULS();
}
class _ULS extends State<_UserListSheet> {
  final _repo = ProfileRepository(ApiClient.instance);
  List<UserModel> _list = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final list = widget.isFollowers
        ? await _repo.getFollowers(widget.userId)
        : await _repo.getFollowing(widget.userId);
    if (mounted) {
      setState(() { _list = list; _loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.65,
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(children: [
      Center(child: Container(width: 36, height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white24,
            borderRadius: BorderRadius.circular(2)))),
      Text(widget.title, style: const TextStyle(color: Colors.white,
          fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Divider(color: Colors.white10),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2))
          : _list.isEmpty
              ? Center(child: Text('Ҳанӯз ${widget.title.toLowerCase()} нест',
                  style: const TextStyle(color: Colors.white30, fontSize: 14)))
              : ListView.builder(itemCount: _list.length, itemBuilder: (_, i) {
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
                      if (u.isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 14),
                      ],
                    ]),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: u.id)));
                    });
                })),
    ]));
}

// ─── Verify Sheet ────────────────────────────────────────────────────────
class _VerifySheet extends StatelessWidget {
  const _VerifySheet();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
    decoration: const BoxDecoration(color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Container(width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Container(width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF00C853).withOpacity(0.12),
            border: Border.all(
                color: const Color(0xFF00C853).withOpacity(0.4), width: 2)),
          child: const Icon(Icons.verified_rounded,
              color: Color(0xFF00C853), size: 36)),
        const SizedBox(height: 16),
        const Text('Raonson Verified', style: TextStyle(color: Colors.white,
            fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Профили тасдиқшуда корбаронро нишон медиҳад, '
            'ки шумо аслӣ ҳастед.',
            style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 13.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: const Text('Тасдиқ дархост кун',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15)))),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор',
                style: TextStyle(color: Colors.white38))),
      ])));
}

// ─── Empty State ─────────────────────────────────────────────────────────
class _Empty extends StatefulWidget {
  final IconData icon; final String label;
  const _Empty({required this.icon, required this.label});
  @override State<_Empty> createState() => _ES();
}
class _ES extends State<_Empty> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _s = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.elasticOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    ScaleTransition(scale: _s,
        child: Icon(widget.icon, size: 52, color: Colors.white12)),
    const SizedBox(height: 10),
    Text(widget.label,
        style: const TextStyle(color: Colors.white30, fontSize: 14)),
  ]));
}
