// lib/navigation/bottom_nav/bottom_nav_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bottom_nav_bar.dart';
import 'bottom_nav_controller.dart';
import '../../app/app_settings.dart';
import '../../core/services/user_session.dart';
import '../../core/services/notification_badge_controller.dart';
import '../../notifications/notifications_repository.dart';
import '../../feed/timeline/feed_screen.dart';
import '../../reels/reels_feed/reels_screen.dart';
import '../../chat/inbox/chat_list_screen.dart';
import '../../search/search_screen.dart';
import '../../profile/profile_screen.dart';
import '../../widgets/account_switcher.dart';
import '../../create/upload/upload_progress_bar.dart';
import '../../widgets/offline_banner.dart';
import '../../core/firebase_init.dart';
import '../../core/services/ad_consent_service.dart';
import '../../core/ads/ads_manager.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../core/webrtc_service.dart';
import '../../chat/room/incoming_call_screen.dart';
import '../../chat/room/call_screen.dart';
import '../../models/user_model.dart';

class BottomNavScaffold extends StatelessWidget {
  const BottomNavScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BottomNavController(),
      child: const _BottomNavView(),
    );
  }
}

class _BottomNavView extends StatefulWidget {
  const _BottomNavView();
  @override
  State<_BottomNavView> createState() => _BottomNavViewState();
}

class _BottomNavViewState extends State<_BottomNavView> {
  Key _feedKey    = UniqueKey();
  Key _reelsKey   = UniqueKey();
  Key _profileKey = UniqueKey();
  Key _chatKey    = UniqueKey();
  Key _searchKey  = UniqueKey();
  final _signal = WebRTCService();
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _lastUserId = UserSession.userId;
    UserSession.userIdNotifier.addListener(_onUserChanged);
    _setupGlobalCalls();
    _setupNotifBadge();
    FirebaseInit.requestNotificationPermission();
    _showAdConsentIfNeeded();
  }

  Future<void> _showAdConsentIfNeeded() async {
    if (AdConsentService.instance.consentGiven) return;
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Таблиғот ва маълумот',
            style: TextStyle(color: Colors.white, fontSize: 17,
                fontWeight: FontWeight.w600)),
        content: const Text(
          'Raonson таблиғоти шахсигардонидашуда нишон медиҳад. '
          'Мо маълумоти дастгоҳро (ID, фаъолият) барои нишон додани '
          'таблиғоти мувофиқ истифода мебарем.\n\n'
          'Шумо метавонед маълумоти бештарро дар Сиёсати махфият хонед.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Рад кардан',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3797F0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Қабул кардан',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await AdConsentService.instance.grantConsent();
      MobileAds.initialize();
      AdsManager.instance.init();
    }
  }

  // Вақте корбар аккаунти дигарро интихоб кард — Feed/Reels/Profile/Chat/
  // Search ҳама Key-и нав мегиранд, то Element-и куҳна нест шавад ва
  // ҳар табҳо аз нав initState → loadX-ро иҷро кунанд бо токени нав.
  void _onUserChanged() {
    final uid = UserSession.userId;
    if (uid == _lastUserId) return;
    _lastUserId = uid;
    if (!mounted) return;
    setState(() {
      _feedKey    = UniqueKey();
      _reelsKey   = UniqueKey();
      _profileKey = UniqueKey();
      _chatKey    = UniqueKey();
      _searchKey  = UniqueKey();
    });
  }

  // Бейҷи огоҳиҳо: realtime socket + бори аввал шумора аз сервер.
  Future<void> _setupNotifBadge() async {
    NotificationBadgeController.instance.wireSocket();
    try {
      final data = await NotificationsRepository().fetchNotifications();
      NotificationBadgeController.instance
          .setCount((data['unreadCount'] as int?) ?? 0);
    } catch (_) {/* best-effort */}
  }

  // Зангҳои воридшаванда дар тамоми барнома қабул мешаванд (на танҳо дар чат).
  Future<void> _setupGlobalCalls() async {
    await _signal.connect();
    _signal.onIncomingCall = (from, fromUsername, fromAvatar, callType) {
      if (!mounted) return;
      final ct = callType == 'video' ? CallType.video : CallType.voice;
      final caller = UserModel(
        id: from,
        username: fromUsername.isNotEmpty ? fromUsername : 'Корбар',
        avatar: fromAvatar,
        verified: false, isPrivate: false,
        postsCount: 0, followersCount: 0, followingCount: 0,
      );
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => IncomingCallScreen(caller: caller, callType: ct),
      ));
    };
  }

  @override
  void dispose() {
    UserSession.userIdNotifier.removeListener(_onUserChanged);
    _signal.onIncomingCall = null;
    super.dispose();
  }

  void _refreshFeed()  => setState(() => _feedKey  = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<BottomNavController>();

    // Тағйири тема/забон фавран ба ҳамаи табҳо татбиқ шавад —
    // вагарна табҳои аллакай сохташуда то иваз кардан кӯҳна мемонанд.
    return AnimatedBuilder(
      animation: AppSettingsState.instance,
      builder: (context, _) => _buildBody(context, nav),
    );
  }

  Widget _buildBody(BuildContext context, BottomNavController nav) {
    // ✅ OfflineBanner — барномаи пурраро мепӯшад
    // Вақте offline → баннер дар боло пайдо мешавад
    return OfflineBanner(
      child: Scaffold(
        body: Stack(
          children: [
            _Tab(
              active: nav.currentIndex == 0,
              child: FeedScreen(
                key: _feedKey,
                isActive: nav.currentIndex == 0,
                onCreatePost: _refreshFeed,
              ),
            ),
            _Tab(
              active: nav.currentIndex == 1,
              child: ReelsScreen(
                key: _reelsKey,
                isActive: nav.currentIndex == 1,
              ),
            ),
            _Tab(active: nav.currentIndex == 2, child: ChatListScreen(key: _chatKey)),
            _Tab(active: nav.currentIndex == 3, child: SearchScreen(key: _searchKey)),
            _Tab(active: nav.currentIndex == 4,
                child: ProfileScreen(key: _profileKey, userId: 'me')),
            // Загрузкаи фонии пост — progress дар боли Home (мисли Instagram)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(bottom: false, child: UploadProgressBar()),
            ),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<String?>(
          valueListenable: UserSession.avatarNotifier,
          builder: (_, liveAvatar, __) => AnimatedBuilder(
            animation: NotificationBadgeController.instance,
            builder: (_, __) => BottomNavBar(
              currentIndex: nav.currentIndex,
              onTap: (i) {
                // Дубора зеркунии tab-и профил → account switcher (мисли Instagram).
                if (i == 4 && nav.currentIndex == 4) {
                  showAccountSwitcher(context);
                } else {
                  nav.setIndex(i);
                }
              },
              onProfileLongPress: () => showAccountSwitcher(context),
              avatarUrl: liveAvatar,
              notifCount: NotificationBadgeController.instance.count,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final bool   active;
  final Widget child;
  const _Tab({required this.active, required this.child, super.key});

  @override
  Widget build(BuildContext context) =>
      Offstage(offstage: !active, child: child);
}
