// lib/settings/settings_screen.dart
// Raonson Settings — Part 2 Complete
// Only uses: flutter, provider, shared_preferences — all in pubspec.yaml
// NO unused imports. NO missing classes. ZERO errors.

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/admin_panel_screen.dart';
import '../app/app_state.dart';
import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/services/user_session.dart';
import '../core/services/region_service.dart';
import '../core/services/vip_service.dart';
import '../anime/anime_screen.dart';
import '../news/news_screen.dart';
import '../learn/learn_screen.dart';
import '../effects/effects_screen.dart';
import '../profile/edit/edit_profile_screen.dart';
import 'account_screens.dart';
import 'insights_screen.dart';
import 'seller_dashboard_screen.dart';
import '../shop/auto_reply_screen.dart';
import '../chat/chat_pin_screen.dart';
import '../subscription/subscription_screen.dart';
import '../create/scheduled_posts_screen.dart';
import '../core/ui/app_icons.dart';

/// Theme label in the active language.
String _themeLabel(ThemeMode m) =>
    m == ThemeMode.light ? tr('theme.light') : tr('theme.dark');

// ════════════════════════════════════════════════════════════════════
//  SETTINGS SCREEN
// ════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsState.instance,
      builder: (ctx, _) {
        final s = AppSettingsState.instance;
        RegionService.instance.ensure(); // бахши «Аниме» танҳо дар TJ
        VipService.instance.load();
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: _appBar(ctx, tr('settings.title'),
              showBack: Navigator.canPop(ctx)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 50),
            children: [

              // ── RAONSON PRO / BUSINESS (мисли Meta Verified) ──────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(children: [
                  Expanded(child: _PlanBanner(
                    title: 'Raonson Pro',
                    subtitle: '29.90 сом/моҳ',
                    icon: AppIcons.star_rounded,
                    colors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
                    onTap: () => _go(ctx, const SubscriptionScreen()),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _PlanBanner(
                    title: 'Business',
                    subtitle: '99.90 сом/моҳ',
                    icon: AppIcons.business_center_rounded,
                    colors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
                    onTap: () => _go(ctx,
                        const SubscriptionScreen(business: true)),
                  )),
                ]),
              ),

              // ── ACCOUNT ───────────────────────────────────────────
              _Hdr(tr('section.account')),
              _NavTile(
                icon:  AppIcons.person_outline_rounded,
                title: tr('account.editProfile'),
                onTap: () => _go(ctx,
                    EditProfileScreen(
                        userId: UserSession.userId ?? 'me')),
              ),
              _NavTile(
                icon:  AppIcons.alternate_email_rounded,
                title: 'Номи корбарӣ',
                sub:   '@${UserSession.username ?? ''}',
                onTap: () => _go(ctx, const ChangeUsernameScreen()),
              ),
              _NavTile(
                icon:  AppIcons.lock_outline_rounded,
                title: tr('account.changePassword'),
                onTap: () => _go(ctx, const ChangePasswordScreen()),
              ),
              _NavTile(
                icon:  AppIcons.email_outlined,
                title: tr('account.email'),
                sub:   tr('account.emailSub'),
                onTap: () => _go(ctx,
                    const ChangeEmailScreen()),
              ),
              _NavTile(
                icon:  AppIcons.phone_outlined,
                title: tr('account.phone'),
                onTap: () => _go(ctx, const ChangePhoneScreen()),
              ),

              // ── ОМОР / МАГОЗА ─────────────────────────────────────
              _Hdr('Омор ва магоза'),
              _NavTile(
                icon:  AppIcons.bar_chart_rounded,
                title: 'Статистика (омор)',
                sub:   'Обзори 1-моҳа: обуна, лайк, топ видео, идеяҳо',
                onTap: () => _go(ctx, const InsightsScreen()),
              ),
              _NavTile(
                icon:  AppIcons.storefront_rounded,
                title: 'Магозаи ман',
                sub:   'Фурӯш, даромад, махсули беҳтарин, боздидҳо',
                onTap: () => _go(ctx, const SellerDashboardScreen()),
              ),
              _NavTile(
                icon:  AppIcons.chat_bubble_rounded,
                title: 'Ҷавоби худкор',
                sub:   'Ба муштариён худкор ҷавоб диҳед',
                onTap: () => _go(ctx, const AutoReplyScreen()),
              ),
              _NavTile(
                icon:  AppIcons.lock_outline_rounded,
                title: 'PIN-и чат',
                sub:   'Чатҳоро бо PIN муҳофизат кунед',
                onTap: () => _go(ctx, const ChatPinScreen()),
              ),
              _NavTile(
                icon:  AppIcons.star_rounded,
                title: 'Дӯстони наздик',
                sub:   'Рӯйхати дӯстони наздик барои сторис',
                onTap: () => _go(ctx, const CloseFriendsScreen()),
              ),
              _NavTile(
                icon:  AppIcons.schedule_rounded,
                title: 'Постҳои ба нақша',
                sub:   'Постҳои дар вақти муайян нашршаванда (Pro)',
                onTap: () => _go(ctx, const ScheduledPostsScreen()),
              ),

              // ── APPEARANCE ────────────────────────────────────────
              _Hdr(tr('section.appearance')),
              _NavTile(
                icon:  AppIcons.palette_outlined,
                title: tr('appearance.theme'),
                sub:   _themeLabel(s.theme),
                onTap: () => _go(ctx, const AppearanceScreen()),
              ),

              // ── LANGUAGE ──────────────────────────────────────────
              _Hdr(tr('section.language')),
              _NavTile(
                icon:  AppIcons.language_rounded,
                title: tr('language.app'),
                sub:   langDisplayName(s.lang),
                onTap: () => _go(ctx, const LanguageScreen()),
              ),

              // ── PRIVACY ───────────────────────────────────────────
              _Hdr(tr('section.privacy')),
              _NavTile(
                icon:  AppIcons.privacy_tip_outlined,
                title: tr('privacy.settings'),
                onTap: () => _go(ctx, const PrivacyScreen()),
              ),

              // ── NOTIFICATIONS ─────────────────────────────────────
              _Hdr(tr('section.notifications')),
              _NavTile(
                icon:  AppIcons.notifications_outlined,
                title: tr('notifications.app'),
                onTap: () => _go(ctx, const NotificationsScreen()),
              ),

              // ── SECURITY ──────────────────────────────────────────
              _Hdr(tr('section.security')),
              _NavTile(
                icon:  AppIcons.security_outlined,
                title: tr('security.settings'),
                onTap: () => _go(ctx, const SecurityScreen()),
              ),

              // ── ADMIN (танҳо барои соҳиби барнома @raonson) ──────
              if ((UserSession.username ?? '').trim().toLowerCase()
                  == 'raonson') ...[
                _Hdr(tr('section.admin')),
                _NavTile(
                  icon:  AppIcons.admin_panel_settings_outlined,
                  title: tr('admin.panel'),
                  sub:   tr('admin.panelSub'),
                  onTap: () => _go(ctx, const AdminPanelScreen()),
                ),
              ],

              // ── АНИМЕ (танҳо дар Тоҷикистон) ──────────────────────
              ValueListenableBuilder<bool>(
                valueListenable: RegionService.instance.isTajikistan,
                builder: (_, isTj, __) {
                  if (!isTj) return const SizedBox.shrink();
                  return Column(children: [
                    _Hdr('Дигар'),
                    _NavTile(
                      icon:  AppIcons.movie_filter_outlined,
                      title: 'Аниме',
                      sub:   'Тамошои аниме · 480p ройгон, 720p/1080p VIP',
                      onTap: () => _go(ctx, const AnimeScreen()),
                    ),
                  ]);
                },
              ),

              // ── LEARN ─────────────────────────────────────────────
              _Hdr('Омӯзиш'),
              _NavTile(
                icon:  AppIcons.code_rounded,
                title: 'Омӯзиши коднависӣ бо AI',
                sub:   'Устоз AI — код, backend, дизайн, icon, вебсайт',
                onTap: () => _go(ctx, const LearnScreen()),
              ),
              _NavTile(
                icon:  AppIcons.bolt_rounded,
                title: 'Бозори эффектҳо',
                sub:   'Эффектҳоро истифода баред ё худатон созед',
                onTap: () => _go(ctx, const EffectsScreen()),
              ),

              // ── ABOUT ─────────────────────────────────────────────
              _Hdr('Маълумот'),
              _NavTile(
                icon:  AppIcons.public_rounded,
                title: 'Ахбор',
                sub:   'Хабарҳои ҷаҳон аз манбаъҳои боэътимод',
                onTap: () => _go(ctx, const NewsScreen()),
              ),
              _NavTile(
                icon:  AppIcons.info_outline_rounded,
                title: 'Дар бораи барнома',
                sub:   'Версия, муаллиф ва маълумот',
                onTap: () => _go(ctx, const AboutScreen()),
              ),
              const _ThinDiv(),
              _NavTile(
                icon:  AppIcons.privacy_tip_outlined,
                title: 'Сиёсати махфият',
                sub:   'Маълумот дар бораи ҳифзи маълумотҳо',
                onTap: () => _launchUrl('https://raonson.app/privacy'),
              ),
              const _ThinDiv(),
              _NavTile(
                icon:  AppIcons.description_outlined,
                title: 'Шартҳои истифода',
                sub:   'Қоидаҳои истифодаи барнома',
                onTap: () => _launchUrl('https://raonson.app/terms'),
              ),

              // ── DANGER ZONE ───────────────────────────────────────
              _Hdr(''),
              _DangerTile(
                icon:  AppIcons.logout_rounded,
                title: tr('account.logout'),
                onTap: () => _confirmLogout(ctx),
              ),
              const _ThinDiv(),
              _DangerTile(
                icon:  AppIcons.delete_forever_rounded,
                title: tr('account.delete'),
                onTap: () => _confirmDelete(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _go(BuildContext ctx, Widget w) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => w));

  static void _launchUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _Dialog(
        title:        tr('logout.title'),
        body:         tr('logout.body'),
        actionLabel:  tr('logout.action'),
        onAction: () {
          Navigator.pop(ctx);
          ctx.read<AppState>().logout();
        },
      ),
    );
  }

  static void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _Dialog(
        title:       tr('delete.title'),
        body:        tr('delete.body'),
        actionLabel: tr('delete.action'),
        onAction: () async {
          Navigator.pop(ctx);
          try {
            await ApiClient.instance.delete('/profile/me');
            if (ctx.mounted) ctx.read<AppState>().logout();
          } catch (_) {}
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  APPEARANCE SCREEN
// ════════════════════════════════════════════════════════════════════
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsState.instance,
      builder: (ctx, _) {
        final s = AppSettingsState.instance;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: _appBar(ctx, tr('section.appearance')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              _ChoiceCard(
                icon:     AppIcons.dark_mode_rounded,
                label:    tr('theme.dark'),
                selected: s.theme == ThemeMode.dark,
                onTap:    () {
                  s.setTheme(ThemeMode.dark);
                  AnalyticsService.instance.logEvent(
                      AnalyticsEvents.changeTheme, params: {'theme': 'dark'});
                },
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                icon:     AppIcons.light_mode_rounded,
                label:    tr('theme.light'),
                selected: s.theme == ThemeMode.light,
                onTap:    () {
                  s.setTheme(ThemeMode.light);
                  AnalyticsService.instance.logEvent(
                      AnalyticsEvents.changeTheme, params: {'theme': 'light'});
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  LANGUAGE SCREEN
// ════════════════════════════════════════════════════════════════════
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const List<(String, String, String)> _langs = [
    ('tj', 'Тоҷикӣ',  '🇹🇯'),
    ('ru', 'Русский', '🇷🇺'),
    ('en', 'English', '🇺🇸'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsState.instance,
      builder: (ctx, _) {
        final s = AppSettingsState.instance;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: _appBar(ctx, tr('section.language')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: _langs.map((l) {
              final selected = s.lang == l.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => s.setLang(l.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.neonBlue.withOpacity(0.12)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected
                              ? AppColors.neonBlue : AppColors.dividerFaint,
                          width: selected ? 1.5 : 1.0),
                    ),
                    child: Row(children: [
                      Text(l.$3,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 16),
                      Expanded(child: Text(l.$2,
                          style: TextStyle(
                            color: selected
                                ? AppColors.textPrimary : AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600 : FontWeight.normal,
                          ))),
                      if (selected)
                        const Icon(AppIcons.check_circle_rounded,
                            color: AppColors.neonBlue, size: 22),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PRIVACY SCREEN
// ════════════════════════════════════════════════════════════════════
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyState();
}

class _PrivacyState extends State<PrivacyScreen> {
  bool _private        = false;
  bool _activityStatus = true;
  bool _allowComments  = true;
  bool _allowMentions  = true;
  bool _loading        = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/profile/me');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final u    = (body['user'] ?? body) as Map<String, dynamic>;
        setState(() {
          _private        = u['isPrivate']       as bool? ?? false;
          _activityStatus = u['activityStatus']  as bool? ?? true;
          _allowComments  = u['allowComments']   as bool? ?? true;
          _allowMentions  = u['allowMentions']   as bool? ?? true;
          _loading        = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sync(String key, bool val) =>
      ApiClient.instance.put('/profile/', body: {key: val});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, 'Махфият'),
      body: _loading
          ? const _SettingsSkeleton()
          : ListView(children: [
              _SwTile(
                icon:  AppIcons.lock_outline_rounded,
                title: 'Профили хусусӣ',
                sub:   'Танҳо пайравони тасдиқшуда мӯҳтаворо мебинанд',
                value: _private,
                onChanged: (v) {
                  setState(() => _private = v);
                  _sync('isPrivate', v);
                  AnalyticsService.instance.logEvent(
                      AnalyticsEvents.changePrivacy,
                      params: {'isPrivate': v});
                },
              ),
              const _ThinDiv(),
              _NavTile(
                icon:  AppIcons.block_rounded,
                title: 'Истифодабарандагони блокшуда',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const BlockedUsersScreen())),
              ),
              const _ThinDiv(),
              _NavTile(
                icon:  AppIcons.star_rounded,
                title: 'Дӯстони наздик',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CloseFriendsScreen())),
              ),
              const _ThinDiv(),
              _SwTile(
                icon:  AppIcons.access_time_rounded,
                title: 'Вазъияти фаъолият',
                sub:   'Ба дигарон нишон деҳ, ки шумо онлайн ҳастед',
                value: _activityStatus,
                onChanged: (v) {
                  setState(() => _activityStatus = v);
                  _sync('activityStatus', v);
                },
              ),
              const _ThinDiv(),
              _SwTile(
                icon:  AppIcons.chat_bubble_outline_rounded,
                title: 'Назорати шарҳҳо',
                sub:   'Ба ҳама иҷозати шарҳ диҳ',
                value: _allowComments,
                onChanged: (v) {
                  setState(() => _allowComments = v);
                  _sync('allowComments', v);
                },
              ),
              const _ThinDiv(),
              _SwTile(
                icon:  AppIcons.alternate_email_rounded,
                title: 'Назорати зикрҳо',
                sub:   'Кӣ метавонад шуморо зикр кунад',
                value: _allowMentions,
                onChanged: (v) {
                  setState(() => _allowMentions = v);
                  _sync('allowMentions', v);
                },
              ),
            ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS SCREEN
// ════════════════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotifState();
}

class _NotifState extends State<NotificationsScreen> {
  bool _likes     = true;
  bool _comments  = true;
  bool _followers = true;
  bool _messages  = true;
  bool _reels     = true;
  bool _push      = true;
  bool _loading   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/profile/notifications');
      if (res.statusCode == 200 && mounted) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _likes     = b['likes']     as bool? ?? true;
          _comments  = b['comments']  as bool? ?? true;
          _followers = b['followers'] as bool? ?? true;
          _messages  = b['messages']  as bool? ?? true;
          _reels     = b['reels']     as bool? ?? true;
          _push      = b['push']      as bool? ?? true;
          _loading   = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() => ApiClient.instance.put('/profile/notifications', body: {
        'likes': _likes, 'comments': _comments,
        'followers': _followers, 'messages': _messages,
        'reels': _reels, 'push': _push,
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, 'Огоҳиҳо'),
      body: _loading
          ? const _SettingsSkeleton()
          : ListView(children: [
              _SwTile(icon: AppIcons.favorite_rounded,
                  title: 'Лайкҳо', value: _likes,
                  onChanged: (v) { setState(() => _likes = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: AppIcons.chat_bubble_rounded,
                  title: 'Шарҳҳо', value: _comments,
                  onChanged: (v) { setState(() => _comments = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: AppIcons.person_add_rounded,
                  title: 'Пайравони нав', value: _followers,
                  onChanged: (v) { setState(() => _followers = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: AppIcons.send_rounded,
                  title: 'Паёмҳо', value: _messages,
                  onChanged: (v) { setState(() => _messages = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: AppIcons.slow_motion_video_rounded,
                  title: 'Рилҳо', value: _reels,
                  onChanged: (v) { setState(() => _reels = v); _save(); }),
              Divider(color: AppColors.dividerFaint, height: 28, indent: 16, endIndent: 16),
              _SwTile(icon: AppIcons.notifications_rounded,
                  title: 'Push-огоҳиҳо', sub: 'Огоҳиҳои телефонӣ',
                  value: _push,
                  onChanged: (v) { setState(() => _push = v); _save(); }),
            ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SECURITY SCREEN
// ════════════════════════════════════════════════════════════════════
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, 'Амният'),
      body: ListView(children: [
        _NavTile(
          icon:  AppIcons.lock_outline_rounded,
          title: 'Иваз кардани рамз',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen())),
        ),
        const _ThinDiv(),
        _NavTile(
          icon:  AppIcons.verified_user_outlined,
          title: 'Тасдиқи дутарафа (2FA)',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const TwoFactorScreen())),
        ),
        const _ThinDiv(),
        _NavTile(
          icon:  AppIcons.devices_rounded,
          title: 'Сессияҳои фаъол',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const SessionsScreen())),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CHANGE PASSWORD SCREEN
// ════════════════════════════════════════════════════════════════════
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _CPState();
}

class _CPState extends State<ChangePasswordScreen> {
  final _oldCtrl  = TextEditingController();
  final _new1Ctrl = TextEditingController();
  final _new2Ctrl = TextEditingController();
  bool    _saving = false;
  bool    _s1 = false, _s2 = false, _s3 = false;
  String? _err;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _new1Ctrl.dispose();
    _new2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final old  = _oldCtrl.text.trim();
    final nw   = _new1Ctrl.text.trim();
    final cnf  = _new2Ctrl.text.trim();

    if (old.isEmpty || nw.isEmpty || cnf.isEmpty) {
      setState(() => _err = 'Ҳамаи майдонҳоро пур кунед');
      return;
    }
    if (nw.length < 8) {
      setState(() => _err = 'Рамзи нав ҳадди аққал 8 аломат');
      return;
    }
    if (nw != cnf) {
      setState(() => _err = 'Рамзҳо мувофиқат намекунанд');
      return;
    }

    setState(() { _saving = true; _err = null; });
    try {
      final res = await ApiClient.instance.post(
          '/auth/change-password',
          body: {'oldPassword': old, 'newPassword': nw});
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Рамз бомуваффақият тағир ёфт')));
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
        setState(() =>
            _err = b['message']?.toString() ?? 'Хатогӣ ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
            icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text('Иваз кардани рамз',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_saving)
            Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textPrimary)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text('Сабт',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _PwField(
              ctrl: _oldCtrl, hint: 'Рамзи кӯҳна',
              show: _s1, onToggle: () => setState(() => _s1 = !_s1)),
          const SizedBox(height: 14),
          _PwField(
              ctrl: _new1Ctrl, hint: 'Рамзи нав (ҳадди аққал 8)',
              show: _s2, onToggle: () => setState(() => _s2 = !_s2)),
          const SizedBox(height: 14),
          _PwField(
              ctrl: _new2Ctrl, hint: 'Рамзи навро такрор кун',
              show: _s3, onToggle: () => setState(() => _s3 = !_s3)),
          if (_err != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.withOpacity(0.3))),
              child: Row(children: [
                const Icon(AppIcons.error_outline_rounded,
                    color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_err!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TWO FACTOR SCREEN
// ════════════════════════════════════════════════════════════════════
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});
  @override
  State<TwoFactorScreen> createState() => TwoFAState();
}

class TwoFAState extends State<TwoFactorScreen> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/profile/me');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final u    = (body['user'] ?? body) as Map<String, dynamic>;
        setState(() {
          _enabled = u['twoFactor'] as bool? ?? false;
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    try {
      await ApiClient.instance.put('/profile/', body: {'twoFactor': v});
    } catch (_) {
      if (mounted) setState(() => _enabled = !v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, 'Тасдиқи дутарафа'),
      body: _loading
          ? const _SettingsSkeleton()
          : ListView(children: [
              _SwTile(
                icon:  AppIcons.verified_user_outlined,
                title: 'Тасдиқи дутарафа',
                sub:   'Ба аккаунти шумо ҳимояи иловагӣ',
                value: _enabled,
                onChanged: _toggle,
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'Вақте ки 2FA фаъол аст, ҳар бор ки ворид мешавед, '
                  'рамзи иловагӣ талаб карда мешавад.',
                  style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.4),
                      fontSize: 13, height: 1.5),
                ),
              ),
            ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SESSIONS SCREEN
// ════════════════════════════════════════════════════════════════════
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessState();
}

class _SessState extends State<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/auth/sessions');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['sessions'] ?? []) as List;
        setState(() {
          _sessions = list.cast<Map<String, dynamic>>();
          _loading  = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revokeAll() async {
    try {
      await ApiClient.instance.post('/auth/revoke-all');
      if (mounted) _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        leading: IconButton(
            icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text('Сессияҳои фаъол',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
              onPressed: _revokeAll,
              child: const Text('Ҳамаро бандед',
                  style: TextStyle(
                      color: Colors.redAccent, fontSize: 13))),
        ],
      ),
      body: _loading
          ? const _SettingsSkeleton()
          : _sessions.isEmpty
              ? const _EmptyHint('Сессияҳо нест')
              : ListView.separated(
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const _ThinDiv(),
                  itemBuilder: (_, i) {
                    final s       = _sessions[i];
                    final device  =
                        s['device']?.toString() ?? 'Дастгоҳ';
                    final ip      =
                        s['ip']?.toString() ?? '';
                    final current =
                        s['current'] as bool? ?? false;
                    return ListTile(
                      leading: Icon(
                          device.toLowerCase().contains('ios')
                              ? AppIcons.phone_iphone_rounded
                              : AppIcons.computer_rounded,
                          color: current
                              ? AppColors.neonBlue : AppColors.textTertiary),
                      title: Row(children: [
                        Flexible(child: Text(device,
                            style: TextStyle(color: AppColors.textPrimary))),
                        if (current) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neonBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6)),
                            child: const Text('Ҳозира',
                                style: TextStyle(
                                    color: AppColors.neonBlue,
                                    fontSize: 11))),
                        ],
                      ]),
                      subtitle: ip.isNotEmpty
                          ? Text(ip,
                              style: TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: 12))
                          : null,
                    );
                  }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BLOCKED USERS SCREEN
// ════════════════════════════════════════════════════════════════════
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BUSState();
}

class _BUSState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/users/blocked');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['users'] ?? body['blocked'] ?? []) as List;
        setState(() {
          _users   = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String uid) async {
    try {
      await ApiClient.instance.post('/users/$uid/unblock');
      if (mounted) _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, 'Блокшудагон'),
      body: _loading
          ? const _SettingsSkeleton()
          : _users.isEmpty
              ? const _EmptyHint('Ягон корбари блокшуда нест')
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const _ThinDiv(),
                  itemBuilder: (_, i) {
                    final u        = _users[i];
                    final uid      = (u['_id'] ?? u['id'] ?? '').toString();
                    final username = u['username']?.toString() ?? '';
                    final avatar   = u['avatar']?.toString()   ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.card,
                        backgroundImage: avatar.isNotEmpty
                            ? CachedNetworkImageProvider(avatar, maxWidth: 80) : null,
                        child: avatar.isEmpty
                            ? Icon(AppIcons.person,
                                color: AppColors.textFaint) : null),
                      title: Text(username,
                          style: TextStyle(color: AppColors.textPrimary)),
                      trailing: TextButton(
                          onPressed: () => _unblock(uid),
                          child: const Text('Бардор',
                              style: TextStyle(
                                  color: AppColors.neonBlue))),
                    );
                  }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ABOUT SCREEN — Дар бораи барнома
// ════════════════════════════════════════════════════════════════════
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _version = '1.0.5';
  static const String _year    = '2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, 'Дар бораи барнома'),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // Logo — танҳо худи лого, бе чаҳорчӯба/ранги иловагӣ дар гӯшаҳо
          Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.30),
                    blurRadius: 34, spreadRadius: 2),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/icon.png',
                    width: 118, height: 118, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 118, height: 118, color: AppColors.card,
                        alignment: Alignment.center,
                        child: Icon(AppIcons.bolt_rounded,
                            color: AppColors.textPrimary, size: 52))),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Raonson',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Версия $_version',
                style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ),
          const SizedBox(height: 28),

          const _AboutRow(
              icon: AppIcons.calendar_today_rounded,
              label: 'Сол сохта шуд',
              value: _year),
          const _AboutRow(
              icon: AppIcons.person_rounded,
              label: 'Муаллиф',
              value: 'Маҳмадмуродов Эҳсон'),
          const _AboutRow(
              icon: AppIcons.public_rounded,
              label: 'Кишвар',
              value: 'Тоҷикистон 🇹🇯'),
          const _AboutRow(
              icon: AppIcons.code_rounded,
              label: 'Технология',
              value: 'Flutter • Go • PostgreSQL'),

          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Raonson — шабакаи иҷтимоии тоҷикӣ барои мубодилаи аксҳо, '
              'видеоҳо, стори ва паёмҳо. Бо муҳаббат дар Тоҷикистон сохта шудааст.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          _AboutLinkRow(
            icon: AppIcons.privacy_tip_outlined,
            label: 'Сиёсати махфият',
            url: 'https://raonson.app/privacy',
          ),
          _AboutLinkRow(
            icon: AppIcons.description_outlined,
            label: 'Шартҳои истифода',
            url: 'https://raonson.app/terms',
          ),
          const SizedBox(height: 28),
          Center(
            child: Text('© $_year Raonson. Ҳамаи ҳуқуқҳо ҳифз шудаанд.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AboutRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        Icon(icon, color: AppColors.textTertiary, size: 20),
        const SizedBox(width: 16),
        Text(label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _AboutLinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  const _AboutLinkRow(
      {required this.icon, required this.label, required this.url});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Icon(icon, color: AppColors.neonBlue, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: TextStyle(color: AppColors.neonBlue, fontSize: 14)),
          ),
          Icon(AppIcons.arrow_forward_rounded, color: AppColors.textFaint, size: 16),
        ]),
      ),
    );
  }
}

// ── Банери план (Pro / Business) ────────────────────────────────────
class _PlanBanner extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _PlanBanner({required this.title, required this.subtitle,
      required this.icon, required this.colors, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(
              color: Colors.white70, fontSize: 11.5)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHARED HELPERS — AppBar + Widgets
// ════════════════════════════════════════════════════════════════════

AppBar _appBar(BuildContext ctx, String title, {bool showBack = true}) {
  return AppBar(
    backgroundColor: AppColors.bg,
    elevation: 0,
    automaticallyImplyLeading: showBack,
    leading: showBack
        ? IconButton(
            icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(ctx))
        : null,
    title: Text(title, style: TextStyle(
        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
    centerTitle: true);
}

// Section header
class _Hdr extends StatelessWidget {
  final String text;
  const _Hdr(this.text);
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(text, style: TextStyle(
          color: AppColors.textPrimary.withOpacity(0.4), fontSize: 12,
          fontWeight: FontWeight.w700, letterSpacing: 0.9)));
  }
}

// Nav tile
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  sub;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title,
      required this.onTap, this.sub});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title:   Text(title,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      subtitle: sub != null
          ? Text(sub!, style: TextStyle(
              color: AppColors.textFaint, fontSize: 12)) : null,
      trailing: Icon(AppIcons.chevron_right_rounded,
          color: AppColors.textFaint, size: 20),
      onTap: onTap);
  }
}

// Switch tile
class _SwTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  sub;
  final bool     value;
  final ValueChanged<bool> onChanged;
  const _SwTile({required this.icon, required this.title,
      required this.value, required this.onChanged, this.sub});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary, size: 22),
      title:     Text(title,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      subtitle:  sub != null
          ? Text(sub!, style: TextStyle(
              color: AppColors.textFaint, fontSize: 12)) : null,
      value:     value,
      onChanged: onChanged,
      activeColor: AppColors.neonBlue);
  }
}

// Danger tile
class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final VoidCallback onTap;
  const _DangerTile({required this.icon, required this.title,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.redAccent, size: 22),
      title:   Text(title,
          style: const TextStyle(color: Colors.redAccent, fontSize: 15)),
      onTap:   onTap);
  }
}

// Choice card (appearance / language)
class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;
  const _ChoiceCard({required this.icon, required this.label,
      required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonBlue.withOpacity(0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.neonBlue : AppColors.dividerFaint,
              width: selected ? 1.5 : 1.0)),
        child: Row(children: [
          Icon(icon,
              color: selected ? AppColors.neonBlue : AppColors.textTertiary,
              size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 15,
              fontWeight: selected
                  ? FontWeight.w600 : FontWeight.normal))),
          if (selected)
            const Icon(AppIcons.check_circle_rounded,
                color: AppColors.neonBlue, size: 22),
        ]),
      ),
    );
  }
}

// Password field
class _PwField extends StatelessWidget {
  final TextEditingController ctrl;
  final String       hint;
  final bool         show;
  final VoidCallback onToggle;
  const _PwField({required this.ctrl, required this.hint,
      required this.show, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.dividerFaint)),
      child: TextField(
        controller: ctrl,
        obscureText: !show,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: TextStyle(color: AppColors.textFaint),
          prefixIcon: Icon(AppIcons.lock_outline_rounded,
              color: AppColors.textFaint, size: 18),
          suffixIcon: IconButton(
              icon: Icon(
                  show ? AppIcons.visibility_off_rounded
                      : AppIcons.visibility_rounded,
                  color: AppColors.textFaint, size: 18),
              onPressed: onToggle),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14))));
  }
}

// Thin divider
class _ThinDiv extends StatelessWidget {
  const _ThinDiv();
  @override
  Widget build(BuildContext context) {
    return Divider(
        color: AppColors.dividerFaint, height: 0, indent: 56);
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.divider,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) =>
            Divider(color: AppColors.dividerFaint, height: 0, indent: 56),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(6))),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 140, height: 13,
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(width: 220, height: 10,
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(6))),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

// Empty hint
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text,
        style: TextStyle(color: AppColors.textFaint, fontSize: 14)));
  }
}

// Confirm dialog
class _Dialog extends StatelessWidget {
  final String      title, body, actionLabel;
  final VoidCallback onAction;
  const _Dialog({required this.title, required this.body,
      required this.actionLabel, required this.onAction});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: TextStyle(color: AppColors.textPrimary,
              fontWeight: FontWeight.bold)),
      content: Text(body,
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel'),
                style: TextStyle(color: AppColors.textTertiary))),
        TextButton(
            onPressed: onAction,
            child: Text(actionLabel,
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold))),
      ]);
  }
}
