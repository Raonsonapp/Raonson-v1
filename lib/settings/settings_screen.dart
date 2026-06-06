// lib/settings/settings_screen.dart
// Raonson Settings — Part 2 Complete
// Only uses: flutter, provider, shared_preferences — all in pubspec.yaml
// NO unused imports. NO missing classes. ZERO errors.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/services/user_session.dart';
import '../profile/edit/edit_profile_screen.dart';

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
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: _appBar(ctx, tr('settings.title'),
              showBack: Navigator.canPop(ctx)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 50),
            children: [

              // ── ACCOUNT ───────────────────────────────────────────
              _Hdr(tr('section.account')),
              _NavTile(
                icon:  Icons.person_outline_rounded,
                title: tr('account.editProfile'),
                onTap: () => _go(ctx,
                    EditProfileScreen(
                        userId: UserSession.userId ?? 'me')),
              ),
              _NavTile(
                icon:  Icons.lock_outline_rounded,
                title: tr('account.changePassword'),
                onTap: () => _go(ctx, const ChangePasswordScreen()),
              ),
              _NavTile(
                icon:  Icons.email_outlined,
                title: tr('account.email'),
                sub:   tr('account.emailSub'),
                onTap: () => _go(ctx,
                    _SimpleScreen(title: tr('account.email'))),
              ),
              _NavTile(
                icon:  Icons.phone_outlined,
                title: tr('account.phone'),
                onTap: () => _go(ctx,
                    _SimpleScreen(title: tr('account.phone'))),
              ),

              // ── APPEARANCE ────────────────────────────────────────
              _Hdr(tr('section.appearance')),
              _NavTile(
                icon:  Icons.palette_outlined,
                title: tr('appearance.theme'),
                sub:   _themeLabel(s.theme),
                onTap: () => _go(ctx, const AppearanceScreen()),
              ),

              // ── LANGUAGE ──────────────────────────────────────────
              _Hdr(tr('section.language')),
              _NavTile(
                icon:  Icons.language_rounded,
                title: tr('language.app'),
                sub:   langDisplayName(s.lang),
                onTap: () => _go(ctx, const LanguageScreen()),
              ),

              // ── PRIVACY ───────────────────────────────────────────
              _Hdr(tr('section.privacy')),
              _NavTile(
                icon:  Icons.privacy_tip_outlined,
                title: tr('privacy.settings'),
                onTap: () => _go(ctx, const PrivacyScreen()),
              ),

              // ── NOTIFICATIONS ─────────────────────────────────────
              _Hdr(tr('section.notifications')),
              _NavTile(
                icon:  Icons.notifications_outlined,
                title: tr('notifications.app'),
                onTap: () => _go(ctx, const NotificationsScreen()),
              ),

              // ── SECURITY ──────────────────────────────────────────
              _Hdr(tr('section.security')),
              _NavTile(
                icon:  Icons.security_outlined,
                title: tr('security.settings'),
                onTap: () => _go(ctx, const SecurityScreen()),
              ),

              // ── DANGER ZONE ───────────────────────────────────────
              _Hdr(''),
              _DangerTile(
                icon:  Icons.logout_rounded,
                title: tr('account.logout'),
                onTap: () => _confirmLogout(ctx),
              ),
              const _ThinDiv(),
              _DangerTile(
                icon:  Icons.delete_forever_rounded,
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
                icon:     Icons.dark_mode_rounded,
                label:    tr('theme.dark'),
                selected: s.theme == ThemeMode.dark,
                onTap:    () => s.setTheme(ThemeMode.dark),
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                icon:     Icons.light_mode_rounded,
                label:    tr('theme.light'),
                selected: s.theme == ThemeMode.light,
                onTap:    () => s.setTheme(ThemeMode.light),
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
                              ? AppColors.neonBlue : Colors.white12,
                          width: selected ? 1.5 : 1.0),
                    ),
                    child: Row(children: [
                      Text(l.$3,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 16),
                      Expanded(child: Text(l.$2,
                          style: TextStyle(
                            color: selected
                                ? Colors.white : Colors.white70,
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600 : FontWeight.normal,
                          ))),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
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
          ? const _Spinner()
          : ListView(children: [
              _SwTile(
                icon:  Icons.lock_outline_rounded,
                title: 'Профили хусусӣ',
                sub:   'Танҳо пайравони тасдиқшуда мӯҳтаворо мебинанд',
                value: _private,
                onChanged: (v) {
                  setState(() => _private = v);
                  _sync('isPrivate', v);
                },
              ),
              const _ThinDiv(),
              _NavTile(
                icon:  Icons.block_rounded,
                title: 'Истифодабарандагони блокшуда',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const BlockedUsersScreen())),
              ),
              const _ThinDiv(),
              _NavTile(
                icon:  Icons.favorite_border_rounded,
                title: 'Дӯстони наздик',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const _SimpleScreen(title: 'Дӯстони наздик'))),
              ),
              const _ThinDiv(),
              _SwTile(
                icon:  Icons.access_time_rounded,
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
                icon:  Icons.chat_bubble_outline_rounded,
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
                icon:  Icons.alternate_email_rounded,
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
          ? const _Spinner()
          : ListView(children: [
              _SwTile(icon: Icons.favorite_rounded,
                  title: 'Лайкҳо', value: _likes,
                  onChanged: (v) { setState(() => _likes = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: Icons.chat_bubble_rounded,
                  title: 'Шарҳҳо', value: _comments,
                  onChanged: (v) { setState(() => _comments = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: Icons.person_add_rounded,
                  title: 'Пайравони нав', value: _followers,
                  onChanged: (v) { setState(() => _followers = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: Icons.send_rounded,
                  title: 'Паёмҳо', value: _messages,
                  onChanged: (v) { setState(() => _messages = v); _save(); }),
              const _ThinDiv(),
              _SwTile(icon: Icons.slow_motion_video_rounded,
                  title: 'Рилҳо', value: _reels,
                  onChanged: (v) { setState(() => _reels = v); _save(); }),
              const Divider(color: Colors.white12, height: 28, indent: 16, endIndent: 16),
              _SwTile(icon: Icons.notifications_rounded,
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
          icon:  Icons.lock_outline_rounded,
          title: 'Иваз кардани рамз',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen())),
        ),
        const _ThinDiv(),
        _NavTile(
          icon:  Icons.verified_user_outlined,
          title: 'Тасдиқи дутарафа (2FA)',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const TwoFactorScreen())),
        ),
        const _ThinDiv(),
        _NavTile(
          icon:  Icons.devices_rounded,
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Иваз кардани рамз',
            style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Сабт',
                  style: TextStyle(
                      color: Colors.white,
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
                const Icon(Icons.error_outline_rounded,
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
          ? const _Spinner()
          : ListView(children: [
              _SwTile(
                icon:  Icons.verified_user_outlined,
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
                      color: Colors.white.withOpacity(0.4),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Сессияҳои фаъол',
            style: TextStyle(color: Colors.white,
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
          ? const _Spinner()
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
                              ? Icons.phone_iphone_rounded
                              : Icons.computer_rounded,
                          color: current
                              ? AppColors.neonBlue : Colors.white54),
                      title: Row(children: [
                        Flexible(child: Text(device,
                            style: const TextStyle(color: Colors.white))),
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
                              style: const TextStyle(
                                  color: Colors.white38,
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
          ? const _Spinner()
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
                            ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? const Icon(Icons.person,
                                color: Colors.white38) : null),
                      title: Text(username,
                          style: const TextStyle(color: Colors.white)),
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
//  SIMPLE PLACEHOLDER SCREEN
// ════════════════════════════════════════════════════════════════════
class _SimpleScreen extends StatelessWidget {
  final String title;
  const _SimpleScreen({required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(context, title),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.construction_rounded,
            size: 52, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 12),
        Text('Дар таҳия аст',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35), fontSize: 14)),
      ])),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(ctx))
        : null,
    title: Text(title, style: const TextStyle(
        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
          color: Colors.white.withOpacity(0.4), fontSize: 12,
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
      leading: Icon(icon, color: Colors.white70, size: 22),
      title:   Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: sub != null
          ? Text(sub!, style: const TextStyle(
              color: Colors.white38, fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Colors.white24, size: 20),
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
      secondary: Icon(icon, color: Colors.white70, size: 22),
      title:     Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle:  sub != null
          ? Text(sub!, style: const TextStyle(
              color: Colors.white38, fontSize: 12)) : null,
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
              color: selected ? AppColors.neonBlue : Colors.white12,
              width: selected ? 1.5 : 1.0)),
        child: Row(children: [
          Icon(icon,
              color: selected ? AppColors.neonBlue : Colors.white54,
              size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 15,
              fontWeight: selected
                  ? FontWeight.w600 : FontWeight.normal))),
          if (selected)
            const Icon(Icons.check_circle_rounded,
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
          border: Border.all(color: Colors.white12)),
      child: TextField(
        controller: ctrl,
        obscureText: !show,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: Colors.white38, size: 18),
          suffixIcon: IconButton(
              icon: Icon(
                  show ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white38, size: 18),
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
    return const Divider(
        color: Colors.white10, height: 0, indent: 56);
  }
}

// Spinner
class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: CircularProgressIndicator(
            color: AppColors.neonBlue, strokeWidth: 2));
  }
}

// Empty hint
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text,
        style: const TextStyle(color: Colors.white38, fontSize: 14)));
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
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold)),
      content: Text(body,
          style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel'),
                style: const TextStyle(color: Colors.white54))),
        TextButton(
            onPressed: onAction,
            child: Text(actionLabel,
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold))),
      ]);
  }
}
