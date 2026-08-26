// lib/profile/profile_screen.dart — Part 1 FIXED

// NO qr_flutter. Share via share_plus.
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shimmer/shimmer.dart';
import '../app/app_theme.dart';
import 'saved_collections_screen.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../core/services/follow_service.dart';
import '../core/services/subscription_service.dart';
import '../create/upload/upload_manager.dart';
import '../feed/post/post_detail_screen.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import '../reels/single_reel_screen.dart';
import '../chat/room/chat_room_screen.dart';
import '../widgets/verified_badge.dart';
import '../widgets/account_switcher.dart';
import 'edit/edit_profile_screen.dart';
import 'highlight_model.dart';
import 'highlight_viewer.dart';
import 'highlights_row.dart';
import 'profile_controller.dart';
import 'profile_repository.dart';
import 'profile_skeleton.dart';
import 'share_profile_sheet.dart';
import '../settings/settings_screen.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/report_dialog.dart';

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
    AnalyticsService.instance.logEvent(AnalyticsEvents.profileView);
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
    // Ҳар бор кушодан → нав мекунем (то посте, ки ҳозир сев/таг шуд,
    // фавран пайдо шавад, на баъди 1-2 дақиқа).
    if (_tab.index == 2) {
      _ctrl.loadTaggedPosts();
    }
    if (_isMe && _tab.index == 3) {
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
      _tile(AppIcons.person_rounded, 'Расмро бин',
          () { Navigator.pop(context); _viewPhoto(); }),
      _tile(AppIcons.photo_library_rounded, 'Галерея',
          () { Navigator.pop(context); _pick(ImageSource.gallery); }),
      _tile(AppIcons.camera_alt_rounded, 'Камера',
          () { Navigator.pop(context); _pick(ImageSource.camera); }),
      if ((_ctrl.profile?.avatar ?? '').isNotEmpty)
        _tile(AppIcons.delete_outline_rounded, 'Расмро нест кун',
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
              imageUrl: url, width: 280, height: 280, fit: BoxFit.cover,
              memCacheWidth: 560))))));
  }

  // ── Highlight tap → viewer ───────────────────────────────────────
  void _openHighlight(HighlightModel h) {
    if (h.items.isEmpty) {
      // Highlight-и кӯҳна (бе items) — танҳо ба соҳиб имкони танзим.
      if (_isMe) _hlLongPress(h);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => HighlightViewer(
        highlight: h,
        isOwner: _isMe,
        onRename: (title) => _ctrl.renameHighlight(h.id, title),
        onDeleteHighlight: () => _ctrl.deleteHighlight(h.id),
        onItemsChanged: (items) async {
          await _ctrl.updateHighlightItems(h.id, items);
        },
      ),
    ));
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
    // Якчанд расм интихоб мекунем (мисли Instagram — маҷмӯаи актуалӣ).
    final picked = await ImagePicker()
        .pickMultiImage(maxWidth: 1080, maxHeight: 1080, imageQuality: 80);
    if (picked.isEmpty || !mounted) return;

    final title = await _askHighlightTitle();
    if (title == null || title.trim().isEmpty || !mounted) return;

    // Loading overlay
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2)),
    );
    final items = <HighlightItem>[];
    for (final p in picked) {
      try {
        final url = await UploadManager().uploadFile(File(p.path));
        if (url.isNotEmpty) items.add(HighlightItem(url: url, type: 'image'));
      } catch (_) {}
    }
    final coverUrl = items.isNotEmpty ? items.first.url : '';
    await _ctrl.createHighlight(title.trim(), coverUrl, const [], items: items);
    if (mounted) Navigator.pop(context); // close loading
  }

  Future<String?> _askHighlightTitle() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Актуальни нав',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ном...',
            hintStyle: TextStyle(color: AppColors.textFaint),
            counterStyle: TextStyle(color: AppColors.textFaint),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textFaint)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.neonBlue)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
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
      _tile(u.isBlocked ? AppIcons.lock_open_rounded : AppIcons.block_rounded,
          u.isBlocked ? 'Блокро бардор' : '${u.username}-ро блок кун',
          () { Navigator.pop(context); _confirmBlock(u.isBlocked); },
          red: !u.isBlocked),
      _tile(AppIcons.flag_outlined, 'Шикоят кун',
          () async {
            Navigator.pop(context);
            final result = await ReportDialog.showWithDescription(context);
            if (result == null) return;
            try {
              await ApiClient.instance.post('/users/${u.id}/report',
                  body: {'reason': result.reason, 'description': result.description});
            } catch (_) {}
            _snack('Шикоят фиристода шуд');
          }),
      _tile(AppIcons.do_not_disturb_on_outlined, 'Маҳдуд кун',
          () async {
            Navigator.pop(context);
            try {
              await ApiClient.instance.post('/users/${u.id}/restrict');
            } catch (_) {}
            _snack('Корбар маҳдуд карда шуд');
          }),
      _tile(AppIcons.link_rounded, 'Линкро нусха кун', () {
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
      backgroundColor: AppColors.card,
      title: Text(cur ? 'Блокро бардор?' : '${u.username}-ро блок кун?',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Text(cur
          ? '${u.username} барнома-и шуморо дида метавонад.'
          : '${u.username} шуморо дида наметавонад.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
        TextButton(onPressed: () { Navigator.pop(context); _ctrl.toggleBlock(); },
            child: Text(cur ? 'Бардор' : 'Блок кун',
                style: const TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold))),
      ]));
  }

  void _postMenu(PostModel p) {
    if (!_isMe) return;
    _sheet([
      _tile(p.isPinned ? AppIcons.push_pin_outlined : AppIcons.push_pin_rounded,
          p.isPinned ? 'Сабтро бардор' : 'Профилда сабт кун',
          () { Navigator.pop(context); _ctrl.togglePinPost(p); }),
      _tile(AppIcons.delete_outline_rounded, 'Нест кун',
          () { Navigator.pop(context); _confirmDelete(p); }, red: true),
    ]);
  }

  void _confirmDelete(PostModel p) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Нест кардан?',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Text('Ин пост тамоман нест мешавад.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0,
            leading: BackButton(color: AppColors.textPrimary)),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.person_off_rounded, size: 56, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text('Корбар ёфт нашуд',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
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

    // Аккаунт закрытый ва ту обуна нести → мӯҳтаво пинҳон (мисли Instagram).
    final locked = !_isMe && user.isPrivate && !user.isFollowing;

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                      icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary, size: 20),
                      onPressed: () => Navigator.maybePop(context))
                  else
                    const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: _isMe ? () => showAccountSwitcher(context) : null,
                    behavior: HitTestBehavior.opaque,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(user.username,
                        style: TextStyle(color: AppColors.textPrimary,
                            fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
                    if (user.isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(AppIcons.verified_rounded,
                          fill: 1, color: Color(0xFF00C853), size: 16),
                    ],
                    // Кулф — аккаунт закрытый аст (то корбар фаҳмад).
                    if (user.isPrivate) ...[
                      const SizedBox(width: 5),
                      Icon(AppIcons.lock_outline_rounded,
                          color: AppColors.textPrimary, size: 15),
                    ],
                    // Нишони PRO / BUSINESS (обунаи фаъол).
                    if (_isMe && SubscriptionService.instance.isPro) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: SubscriptionService.instance.isBusiness
                                  ? const [Color(0xFFF7971E), Color(0xFFFFD200)]
                                  : const [Color(0xFF7F00FF), Color(0xFFE100FF)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                            SubscriptionService.instance.isBusiness
                                ? 'BUSINESS' : 'PRO',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ),
                    ],
                    if (_isMe) ...[
                      const SizedBox(width: 4),
                      Icon(AppIcons.keyboard_arrow_down_rounded,
                          color: AppColors.textPrimary, size: 22),
                    ],
                  ]))),
                  IconButton(icon: Icon(AppIcons.share_outlined,
                      color: AppColors.textPrimary, size: 20),
                      onPressed: _shareProfile),
                  _isMe
                      ? IconButton(
                          icon: Icon(AppIcons.more_horiz_rounded,
                              color: AppColors.textPrimary, size: 22),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())))
                      : IconButton(
                          icon: Icon(AppIcons.more_vert_rounded,
                              color: AppColors.textPrimary, size: 22),
                          onPressed: _otherMenu),
                ]),
              )),

              // ── COVER BANNER (Pro) ──────────────────────────────────
              if (user.coverUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: CachedNetworkImage(
                      imageUrl: user.coverUrl,
                      width: double.infinity, height: 130, fit: BoxFit.cover,
                      memCacheWidth: 800,
                      placeholder: (_, __) => Container(
                          height: 130, color: AppColors.surface),
                      errorWidget: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),

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
                  child: Text(user.fullName!, style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.bold))),

              // ── BIO ─────────────────────────────────────────────────
              if ((user.bio ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16,
                      (user.fullName ?? '').isNotEmpty ? 4 : 12, 16, 0),
                  child: Text(user.bio!, style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13.5, height: 1.45))),

              // ── WEBSITE ─────────────────────────────────────────────
              if ((user.website ?? '').isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                  child: GestureDetector(
                    onTap: () => _launchWeb(user.website!),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.link_rounded,
                          color: AppColors.neonBlue, size: 14),
                      const SizedBox(width: 5),
                      Text(user.website!, style: const TextStyle(
                          color: AppColors.neonBlue,
                          fontSize: 13.5, fontWeight: FontWeight.w500)),
                    ]))),

              // ── BIO LINKS (Pro — зиёда аз як линк) ──────────────────
              if (user.links.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                  child: Wrap(spacing: 8, runSpacing: 6,
                    children: user.links.map((l) {
                      final title = (l['title'] ?? '').isNotEmpty
                          ? l['title']! : l['url']!;
                      return GestureDetector(
                        onTap: () => _launchWeb(l['url']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(AppIcons.link_rounded,
                                color: AppColors.neonBlue, size: 13),
                            const SizedBox(width: 5),
                            Text(title,
                                style: const TextStyle(color: AppColors.neonBlue,
                                    fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      );
                    }).toList()),
                ),

              // ── HIGHLIGHTS ──────────────────────────────────────────
              const SizedBox(height: 12),
              HighlightsRow(
                highlights:  _ctrl.highlights,
                isMe:        _isMe,
                onAdd:       _isMe ? _createHighlight : null,
                onOpen:      _openHighlight,
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
                        onFollow:  () {
                          AnalyticsService.instance.logEvent(user.isFollowing
                              ? AnalyticsEvents.unfollowUser
                              : AnalyticsEvents.followUser);
                          _ctrl.toggleFollow();
                        },
                        onMessage: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ChatRoomScreen(peer: user))))),

              // ── MUTUAL ──────────────────────────────────────────────
              if (!_isMe && _mutualTxt(user).isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(children: [
                    Icon(AppIcons.people_outline_rounded,
                        color: AppColors.textFaint, size: 14),
                    const SizedBox(width: 6),
                    Flexible(child: Text(_mutualTxt(user),
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12.5),
                        maxLines: 2)),
                  ])),

              // ── TAB BAR (танҳо вақте пӯшида нест) ───────────────────
              if (!locked) ...[
                const SizedBox(height: 12),
                TabBar(
                  controller: _tab,
                  tabs: [
                    const Tab(icon: Icon(AppIcons.grid_on_rounded)),
                    Tab(icon: AnimatedBuilder(
                      animation: _tab,
                      builder: (_, __) => SvgPicture.asset(
                          'assets/icons/nav_reels.svg',
                          width: 22, height: 22,
                          colorFilter: ColorFilter.mode(
                              _tab.index == 1 ? AppColors.textPrimary : AppColors.textFaint,
                              BlendMode.srcIn)),
                    )),
                    const Tab(icon: Icon(AppIcons.person_pin_outlined)),
                    if (_isMe)
                      const Tab(icon: Icon(AppIcons.bookmark_border_rounded)),
                  ],
                  indicatorColor:       AppColors.textPrimary,
                  indicatorWeight:      2,
                  indicatorSize:        TabBarIndicatorSize.tab,
                  labelColor:           AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textFaint,
                  dividerColor:         AppColors.dividerFaint,
                ),
              ],
            ]))],
        body: locked
            ? const _PrivateAccountView()
            : TabBarView(controller: _tab, children: [
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
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_bar(), ...items, const SizedBox(height: 8)])));

  Widget _bar() => Center(child: Container(width: 36, height: 4,
    margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: AppColors.textFaint,
        borderRadius: BorderRadius.circular(2))));

  Widget _tile(IconData icon, String label, VoidCallback onTap,
      {bool red = false}) =>
      ListTile(
        leading: Icon(icon, color: red ? Colors.redAccent : AppColors.textPrimary),
        title: Text(label, style: TextStyle(
            color: red ? Colors.redAccent : AppColors.textPrimary, fontSize: 16)),
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
        border: Border.all(color: AppColors.dividerFaint, width: 1.5)),
    child: ClipOval(child: url.isNotEmpty
        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 450,
            width: size, height: size,
            placeholder: (_, __) => Container(color: AppColors.card),
            errorWidget: (_, __, ___) => _icon(size))
        : _icon(size)));
  Widget _icon(double s) => Container(color: AppColors.card,
      child: Icon(AppIcons.person_rounded, color: AppColors.textFaint, size: s*.5));
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
      Text(_f(n), style: TextStyle(color: AppColors.textPrimary,
          fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5)),
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
        icon: AppIcons.edit_rounded, onTap: onEdit)),
    const SizedBox(width: 8),
    Expanded(child: _Btn(label: 'Мубодила',
        icon: AppIcons.share_rounded, onTap: onShare)),
    const SizedBox(width: 8),
    GestureDetector(onTap: verified ? null : onVerify,
      child: Container(height: 36, width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF00C853).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF00C853).withOpacity(0.5))),
        child: const Icon(AppIcons.verified_rounded,
            fill: 1, color: Color(0xFF00C853), size: 20))),
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
  Widget build(BuildContext context) {
    final muted = isFollowing || followRequestSent;
    return Row(children: [
      // ── Пайравӣ / Пайравишуда ──
      Expanded(child: GestureDetector(
        onTap: followRequestSent ? null : onFollow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 34,
          decoration: BoxDecoration(
            color: muted ? AppColors.surface : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(10),
            border: muted ? Border.all(color: AppColors.dividerFaint) : null),
          child: Center(child: Text(_label, style: TextStyle(
            color: muted ? AppColors.textPrimary : AppColors.bg,
            fontWeight: FontWeight.bold, fontSize: 13.5)))))),
      const SizedBox(width: 8),
      // ── Паём (баробар бо тугмаи боло, бе icon) ──
      Expanded(child: GestureDetector(onTap: onMessage,
        behavior: HitTestBehavior.opaque,
        child: Container(height: 34,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            color: AppColors.surface, border: Border.all(color: AppColors.dividerFaint)),
          child: Center(child: Text('Паём', style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold,
              fontSize: 13.5)))))),
    ]);
  }
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(height: 36,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
        color: AppColors.surface, border: Border.all(color: AppColors.dividerFaint)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AppColors.textPrimary, size: 14),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(color: AppColors.textPrimary,
            fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis)),
      ])));
}

// ─── Private account view (мисли Instagram «Это закрытый профиль») ──────
class _PrivateAccountView extends StatelessWidget {
  const _PrivateAccountView();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 60),
      children: [
        Column(children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 2.5),
            ),
            child: Icon(AppIcons.lock_outline_rounded,
                color: AppColors.textPrimary, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Ин аккаунти пӯшида аст',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Барои дидани публикатсияҳо, ба ин аккаунт обуна шавед. '
              'Дӯстон дар Raonson метавонанд бо ҳам нома нависанд ва '
              'сторисҳои якдигарро бинанд.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14,
                  height: 1.4)),
          ),
        ]),
      ],
    );
  }
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
      return const _Empty(icon: AppIcons.grid_off_rounded, label: 'Ҳанӯз пост нест');
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
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 450,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(color: AppColors.card))
                : Container(color: AppColors.card,
                    child: Icon(AppIcons.image_outlined,
                        color: AppColors.textFaint, size: 28)),
            if (p.media.length > 1)
              Positioned(top: 6, right: 6, child: Icon(
                  AppIcons.collections_rounded, color: AppColors.textPrimary, size: 16,
                  shadows: [Shadow(blurRadius: 4, color: AppColors.bg)])),
            if (p.isPinned)
              Positioned(top: 6, left: 6, child: Icon(
                  AppIcons.push_pin_rounded, color: AppColors.textPrimary, size: 15,
                  shadows: [Shadow(blurRadius: 4, color: AppColors.bg)])),
            Positioned(bottom: 5, left: 5,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(AppIcons.remove_red_eye_rounded,
                    fill: 1, color: AppColors.textPrimary, size: 11,
                    shadows: [Shadow(blurRadius: 4, color: AppColors.bg)]),
                const SizedBox(width: 2),
                Text(_f(p.likesCount), style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 10,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: AppColors.bg)])),
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
  // Placeholder-и оддӣ (бе icon дар мобайн) — мисли Instagram, вақте
  // ки thumbnail ҳанӯз нест. Icon-и reels танҳо дар кунҷи боло мемонад.
  Widget _reelPlaceholder() => Container(color: AppColors.card);
  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return const _Empty(icon: AppIcons.videocam_off_rounded,
          label: 'Ҳанӯз рил нест');
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
          childAspectRatio: 0.65),
      itemCount: reels.length,
      itemBuilder: (ctx, i) {
        final r     = reels[i];
        // Танҳо thumbnail-и воқеӣ ҳамчун расм (видео URL-ро ҳамчун расм
        // бор накунем — он шикаста менамуд). Вагарна placeholder + play.
        final thumb = r.thumbnailUrl;
        return GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => SingleReelScreen(reel: r))),
          child: Stack(fit: StackFit.expand, children: [
          thumb.isNotEmpty
              ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, memCacheWidth: 450,
                  placeholder: (_, __) => Container(color: AppColors.card),
                  errorWidget: (_, __, ___) => _reelPlaceholder())
              : _reelPlaceholder(),
          Positioned(bottom: 0, left: 0, right: 0, height: 44,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
          Positioned(top: 6, right: 6, child: SvgPicture.asset(
              'assets/icons/nav_reels.svg', width: 16, height: 16,
              colorFilter: ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn))),
          Positioned(bottom: 5, left: 5,
            child: Row(children: [
              Icon(AppIcons.remove_red_eye_rounded, fill: 1, color: AppColors.textPrimary,
                  size: 11, shadows: [Shadow(blurRadius: 4, color: AppColors.bg)]),
              const SizedBox(width: 3),
              Text(_f(r.viewsCount), style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: AppColors.bg)])),
            ])),
        ]));
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
      return const _Empty(icon: AppIcons.person_pin_outlined,
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
            imageUrl: posts[i].mediaUrl, fit: BoxFit.cover, memCacheWidth: 450,
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
    // Сатри папкаҳо ҳамеша мебарояд — то корбар папкаи нав созад,
    // ҳатто вақте ҳанӯз пости захирашуда нест.
    if (posts.isEmpty) {
      return ListView(children: const [
        CollectionsRow(),
        SizedBox(height: 40),
        _Empty(icon: AppIcons.bookmark_border_rounded,
            label: 'Сохташудаҳо нест'),
      ]);
    }
    return Column(children: [
      const CollectionsRow(),
      Expanded(
        child: GridView.builder(
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
                memCacheWidth: 450,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => Container(color: AppColors.card))),
        ),
      ),
    ]);
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
  final _searchCtrl = TextEditingController();
  List<UserModel> _list = []; bool _loading = true;
  String _query = '';

  @override void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() =>
        setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final list = widget.isFollowers
        ? await _repo.getFollowers(widget.userId)
        : await _repo.getFollowing(widget.userId);
    if (mounted) {
      setState(() { _list = list; _loading = false; });
    }
  }

  List<UserModel> get _filtered {
    if (_query.isEmpty) return _list;
    return _list.where((u) =>
        u.username.toLowerCase().contains(_query) ||
        (u.fullName ?? '').toLowerCase().contains(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Center(child: Container(width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2)))),
        Text(widget.title, style: TextStyle(color: AppColors.textPrimary,
            fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        // Ҷустуҷӯ — мисли Instagram
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 38,
            decoration: BoxDecoration(color: AppColors.divider,
                borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ҷустуҷӯ',
                hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 14),
                prefixIcon: Icon(AppIcons.search, color: AppColors.textFaint, size: 19),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _loading
            ? _UserListSkeleton()
            : list.isEmpty
                ? Center(child: Text(_query.isNotEmpty
                        ? 'Натиҷае нест'
                        : 'Ҳанӯз ${widget.title.toLowerCase()} нест',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 14)))
                : ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
                    final u = list[i];
                    return ListTile(
                      leading: CircleAvatar(radius: 22,
                        backgroundColor: AppColors.card,
                        backgroundImage: u.avatar.isNotEmpty
                            ? CachedNetworkImageProvider(u.avatar, maxWidth: 88) : null,
                        child: u.avatar.isEmpty
                            ? Icon(AppIcons.person, color: AppColors.textFaint) : null),
                      title: Row(children: [
                        Flexible(child: Text(u.username,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
                        if (u.isVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14),
                        ],
                      ]),
                      subtitle: (u.fullName ?? '').isNotEmpty
                          ? Text(u.fullName!, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textFaint, fontSize: 12.5))
                          : null,
                      trailing: _UserFollowBtn(user: u),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: u.id)));
                      });
                  })),
      ]));
  }
}

class _UserListSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withOpacity(0.4),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: 10,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 12,
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Container(width: 80, height: 10,
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
            Container(width: 70, height: 28,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(6))),
          ]),
        ),
      ),
    );
  }
}

// ── Per-row follow/unfollow button (ҳолати глобалӣ, худро нишон намедиҳад) ──
class _UserFollowBtn extends StatelessWidget {
  final UserModel user;
  const _UserFollowBtn({required this.user});

  bool get _isMe => user.id == (UserSession.userId ?? '__none__');

  @override
  Widget build(BuildContext context) {
    if (_isMe) return const SizedBox.shrink();
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: FollowService.instance.states,
      builder: (_, __, ___) {
        final following = FollowService.instance.resolve(user.id, user.isFollowing);
        return SizedBox(
          height: 32, width: 104,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: following ? AppColors.divider : AppColors.neonBlue,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => FollowService.instance.toggle(user.id, following),
            child: Text(following ? 'Пайравӣ шуд' : 'Пайравӣ',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

// ─── Verify Sheet ────────────────────────────────────────────────────────
class _VerifySheet extends StatelessWidget {
  const _VerifySheet();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Container(width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Container(width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF00C853).withOpacity(0.12),
            border: Border.all(
                color: const Color(0xFF00C853).withOpacity(0.4), width: 2)),
          child: const Icon(AppIcons.verified_rounded,
              fill: 1, color: Color(0xFF00C853), size: 36)),
        const SizedBox(height: 16),
        Text('Raonson Verified', style: TextStyle(color: AppColors.textPrimary,
            fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Профили тасдиқшуда корбаронро нишон медиҳад, '
            'ки шумо аслӣ ҳастед.',
            style: TextStyle(color: AppColors.textPrimary.withOpacity(0.55),
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
          child: Text('Тасдиқ дархост кун',
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold, fontSize: 15)))),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Бекор',
                style: TextStyle(color: AppColors.textFaint))),
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
        child: Icon(widget.icon, size: 52, color: AppColors.dividerFaint)),
    const SizedBox(height: 10),
    Text(widget.label,
        style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
  ]));
}
