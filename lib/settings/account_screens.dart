// lib/settings/account_screens.dart
// Иваз кардани username, номер ва «Дӯстони наздик» — мисли Instagram.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../models/user_model.dart';
import '../profile/profile_repository.dart';
import '../widgets/avatar.dart';
import '../widgets/verified_badge.dart';

// ════════════════════════════════════════════════════════════════════
//  ИВАЗ КАРДАНИ USERNAME
// ════════════════════════════════════════════════════════════════════
class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});
  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameState();
}

class _ChangeUsernameState extends State<ChangeUsernameScreen> {
  late final TextEditingController _ctrl =
      TextEditingController(text: UserSession.username ?? '');
  bool _saving = false;
  String? _err;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final u = _ctrl.text.trim().toLowerCase();
    if (u.isEmpty) { setState(() => _err = 'Номро нависед'); return; }
    if (u == (UserSession.username ?? '').toLowerCase()) {
      Navigator.pop(context); return;
    }
    if (!RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(u)) {
      setState(() => _err =
          'Танҳо ҳарфҳои хурд, рақам, _ ва . (3–30 аломат)');
      return;
    }
    setState(() { _saving = true; _err = null; });
    try {
      final res = await ApiClient.instance
          .put('/profile/username', body: {'username': u});
      if (!mounted) return;
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
        UserSession.username = (b['username'] ?? u).toString();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ном иваз шуд ✓'), backgroundColor: Colors.green));
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
        setState(() => _err = b['message']?.toString() ?? 'Хатогӣ');
      }
    } catch (e) {
      if (mounted) setState(() => _err = 'Шабака нашуд');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(context, 'Номи корбарӣ', _saving, _submit),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
            ],
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixText: '@',
              prefixStyle: TextStyle(color: AppColors.textFaint, fontSize: 16),
              hintText: 'username',
              hintStyle: TextStyle(color: AppColors.textFaint),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Text('Номи корбариро метавонед иваз кунед. Онро дӯстонатон '
              'барои ёфтани шумо истифода мебаранд.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ИВАЗ КАРДАНИ НОМЕР
// ════════════════════════════════════════════════════════════════════
class ChangePhoneScreen extends StatefulWidget {
  final String initial;
  const ChangePhoneScreen({super.key, this.initial = ''});
  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneState();
}

class _ChangePhoneState extends State<ChangePhoneScreen> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _err;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final p = _ctrl.text.trim();
    setState(() { _saving = true; _err = null; });
    try {
      final res = await ApiClient.instance
          .put('/profile/phone', body: {'phone': p});
      if (!mounted) return;
      if (res.statusCode < 400) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Номер сабт шуд ✓'), backgroundColor: Colors.green));
      } else {
        setState(() => _err = 'Хатогӣ ${res.statusCode}');
      }
    } catch (_) {
      if (mounted) setState(() => _err = 'Шабака нашуд');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(context, 'Рақами телефон', _saving, _submit),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '+992 …',
              hintStyle: TextStyle(color: AppColors.textFaint),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Text('Рақами телефони шумо махфӣ мемонад ва барои барқарорсозии '
              'ҳисоб истифода мешавад.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CHANGE EMAIL
// ════════════════════════════════════════════════════════════════════
class ChangeEmailScreen extends StatefulWidget {
  final String initial;
  const ChangeEmailScreen({super.key, this.initial = ''});
  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailState();
}

class _ChangeEmailState extends State<ChangeEmailScreen> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _err;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _ctrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _err = 'Почтаи электронӣ нодуруст');
      return;
    }
    setState(() { _saving = true; _err = null; });
    try {
      final res = await ApiClient.instance
          .put('/profile/email', body: {'email': email});
      if (!mounted) return;
      if (res.statusCode < 400) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Email сабт шуд'), backgroundColor: Colors.green));
      } else {
        setState(() => _err = 'Хатогӣ ${res.statusCode}');
      }
    } catch (_) {
      if (mounted) setState(() => _err = 'Шабака нашуд');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(context, 'Почтаи электронӣ', _saving, _submit),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'name@example.com',
              hintStyle: TextStyle(color: AppColors.textFaint),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Text('Почтаи электронӣ барои барқарорсозии ҳисоб '
              'ва огоҳиҳои муҳим истифода мешавад.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ДӮСТОНИ НАЗДИК (Close friends)
// ════════════════════════════════════════════════════════════════════
class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({super.key});
  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsState();
}

class _CloseFriendsState extends State<CloseFriendsScreen> {
  final _repo = ProfileRepository(ApiClient.instance);
  List<UserModel> _following = [];
  final Set<String> _close = {};
  final Set<String> _busy = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myId = UserSession.userId ?? '';
    try {
      _following = await _repo.getFollowing(myId);
      final res = await ApiClient.instance.get('/close-friends/ids');
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        final ids = (b['ids'] ?? []) as List;
        _close.addAll(ids.map((e) => e.toString()));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(UserModel u) async {
    if (_busy.contains(u.id)) return;
    final wasClose = _close.contains(u.id);
    setState(() {
      _busy.add(u.id);
      if (wasClose) { _close.remove(u.id); } else { _close.add(u.id); }
    });
    try {
      final res = wasClose
          ? await ApiClient.instance.delete('/close-friends/${u.id}')
          : await ApiClient.instance.post('/close-friends/${u.id}');
      if (res.statusCode >= 400 && mounted) {
        setState(() => wasClose ? _close.add(u.id) : _close.remove(u.id));
      }
    } catch (_) {
      if (mounted) setState(() => wasClose ? _close.add(u.id) : _close.remove(u.id));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
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
        title: Text('Дӯстони наздик',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? Shimmer.fromColors(
              baseColor: AppColors.card,
              highlightColor: AppColors.divider,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Container(height: 13, width: 120,
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(6)))),
                    Container(width: 24, height: 24,
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(4))),
                  ]),
                ),
              ),
            )
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Icon(AppIcons.star_rounded,
                      color: const Color(0xFF00C853), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                      'Танҳо дӯстони наздик сторисҳои «наздик»-и шуморо '
                      'мебинанд. Онҳо огоҳ намешаванд.',
                      style: TextStyle(
                          color: AppColors.textFaint, fontSize: 12.5))),
                ]),
              ),
              Divider(color: AppColors.dividerFaint, height: 20),
              Expanded(
                child: _following.isEmpty
                    ? Center(child: Text('Ҳанӯз касеро пайравӣ намекунед',
                        style: TextStyle(color: AppColors.textFaint)))
                    : ListView.builder(
                        itemCount: _following.length,
                        itemBuilder: (_, i) {
                          final u = _following[i];
                          final on = _close.contains(u.id);
                          return ListTile(
                            leading: Avatar(
                                imageUrl: u.avatar, size: 44, name: u.username),
                            title: Row(children: [
                              Flexible(child: Text(u.username,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600))),
                              if (u.verified) ...[
                                const SizedBox(width: 4),
                                const VerifiedBadge(size: 14),
                              ],
                            ]),
                            trailing: Icon(
                              on ? AppIcons.check_circle_rounded
                                 : AppIcons.circle,
                              color: on ? const Color(0xFF00C853)
                                        : AppColors.textFaint,
                              size: 26,
                            ),
                            onTap: () => _toggle(u),
                          );
                        }),
              ),
            ]),
    );
  }
}

// ── AppBar-и муштарак бо тугмаи «Сабт» ──────────────────────────────
PreferredSizeWidget _bar(BuildContext context, String title, bool saving,
    VoidCallback onSave) {
  return AppBar(
    backgroundColor: AppColors.bg,
    elevation: 0,
    leading: IconButton(
        icon: Icon(AppIcons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context)),
    title: Text(title,
        style: TextStyle(color: AppColors.textPrimary,
            fontSize: 16, fontWeight: FontWeight.bold)),
    centerTitle: true,
    actions: [
      if (saving)
        Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textPrimary)),
        )
      else
        TextButton(
          onPressed: onSave,
          child: Text('Сабт',
              style: TextStyle(color: AppColors.neonBlue,
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ),
    ],
  );
}
