// lib/auth/register/register_flow_screen.dart
// Регистратсияи 4-қадама мисли Instagram:
// 1/4 маълумот → 2/4 номи корбар → 3/4 акс → 4/4 пайдо кардани дӯстон.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_settings.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/services/user_session.dart';
import '../../core/services/account_manager.dart';
import '../../core/storage/token_storage.dart';
import '../../create/upload/upload_manager.dart';
import '../widgets/auth_kit.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // ── Step 1 ──
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _terms = false;

  // ── Step 2 ──
  final _userCtrl = TextEditingController();
  bool?  _usernameAvailable;
  bool   _checkingUsername = false;
  Timer? _debounce;

  // ── Step 3 ──
  File? _avatar;

  // ── Shared ──
  bool   _loading = false;
  String? _error;
  bool   _accountCreated = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _debounce?.cancel();
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl, _confirmCtrl, _userCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goto(int page) {
    setState(() { _page = page; _error = null; });
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _back() {
    if (_page == 0) {
      Navigator.pop(context);
    } else if (_page <= 1) {
      _goto(_page - 1);
    }
    // Баъд аз сохтани ҳисоб (қадами 3-4) бозгашт ба қадами қаблӣ нест.
  }

  // ── STEP 1 → 2 ──
  void _submitStep1() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;
    if (name.isEmpty) return _err(tr('auth.err.fullName'));
    if (!email.contains('@') || !email.contains('.')) {
      return _err(tr('auth.err.email'));
    }
    // Телефон ҳатмӣ — барои барқарорсозии аккаунт (рамз ба ҳамин рақам меояд)
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) {
      return _err(tr('auth.err.phone'));
    }
    if (pass.length < 8) return _err(tr('auth.err.passwordLength'));
    if (pass != _confirmCtrl.text) return _err(tr('auth.err.passwordMismatch'));
    if (!_terms) return _err(tr('auth.err.terms'));
    _goto(1);
  }

  // ── Username availability (debounced) ──
  void _onUsernameChanged(String v) {
    _debounce?.cancel();
    setState(() {
      _usernameAvailable = null;
      _checkingUsername = v.trim().length >= 3;
    });
    if (v.trim().length < 3) {
      setState(() => _checkingUsername = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _checkUsername(v.trim()));
  }

  Future<void> _checkUsername(String uname) async {
    try {
      final res = await ApiClient.instance.get('/auth/check-username/$uname');
      if (!mounted) return;
      bool avail = false;
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        avail = b['available'] == true && b['valid'] == true;
      }
      setState(() { _usernameAvailable = avail; _checkingUsername = false; });
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  // ── STEP 2 → create account → 3 ──
  Future<void> _submitUsername() async {
    final uname = _userCtrl.text.trim().toLowerCase();
    if (uname.length < 3) return _err(tr('auth.err.usernameLength'));
    if (_usernameAvailable == false) return _err(tr('auth.err.usernameTaken'));
    setState(() { _loading = true; _error = null; });
    final ok = await _createAccount(uname);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) { _accountCreated = true; _goto(2); }
  }

  Future<bool> _createAccount(String uname) async {
    try {
      final res = await ApiClient.instance.post(ApiEndpoints.register, body: {
        'username': uname,
        'email':    _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'fullName': _nameCtrl.text.trim(),
        'phone':    _phoneCtrl.text.trim(),
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        Map body = {};
        try { body = jsonDecode(res.body); } catch (_) {}
        _err(body['message']?.toString() ?? tr('auth.err.registerFailed'));
        return false;
      }
      // Auto-login
      final loginRes = await ApiClient.instance.post(ApiEndpoints.login, body: {
        'email':    _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });
      if (loginRes.statusCode == 200) {
        final data  = jsonDecode(loginRes.body) as Map<String, dynamic>;
        final token = data['accessToken']?.toString() ?? '';
        if (token.isNotEmpty) {
          await TokenStorage.saveAccessToken(token);
          ApiClient.instance.setAuthToken(token);
          final refresh = data['refreshToken']?.toString() ?? '';
          if (refresh.isNotEmpty) await TokenStorage.saveRefreshToken(refresh);
          final user = data['user'] as Map<String, dynamic>?;
          if (user != null) {
            final uid = (user['id'] ?? user['_id'])?.toString() ?? '';
            if (uid.isNotEmpty) {
              await TokenStorage.saveUserId(uid);
              UserSession.userId   = uid;
              UserSession.username = uname;
              await AccountManager.upsertCurrent(
                userId: uid, username: uname, avatar: '',
                token: token, refreshToken: refresh);
            }
          }
        }
      }
      return true;
    } catch (e) {
      _err(e.toString().replaceAll('Exception:', '').trim());
      return false;
    }
  }

  // ── STEP 3 avatar ──
  Future<void> _pickAvatar() async {
    // maxWidth/maxHeight — расмро ҳангоми интихоб хурд мекунад, то UI шах
    // нашавад (расми пурраи телефон 4000x3000 ≈ 48MB bitmap → шах).
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
    if (x != null && mounted) setState(() => _avatar = File(x.path));
  }

  Future<void> _submitAvatar() async {
    if (_avatar != null) {
      setState(() => _loading = true);
      try {
        final url = await UploadManager().uploadFile(_avatar!);
        if (url.isNotEmpty) {
          await ApiClient.instance.put('/profile/', body: {'avatar': url});
          UserSession.avatar = url;
        }
      } catch (_) {}
    }
    if (mounted) { setState(() => _loading = false); _goto(3); }
  }

  // ── STEP 4 finish ──
  void _finish() {
    context.read<AppState>().login();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _err(String m) {
    if (mounted) setState(() => _error = m);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Listen to AppSettingsState so tr() re-runs when the language flips.
    return AnimatedBuilder(
      animation: AppSettingsState.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.bg,
      body: AuthBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: back + step + lang
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                child: Row(
                  children: [
                    if (_page <= 1)
                      IconButton(
                        icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 18),
                        onPressed: _back,
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(child: StepProgress(current: _page + 1)),
                    const SizedBox(width: 12),
                    const LangChip(),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _step1(),
                    _step2(),
                    _step3(),
                    _step4(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _scroll(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)));

  Widget _loginLink() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('auth.alreadyHaveAccount'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(tr('auth.loginLink'),
                  style: const TextStyle(
                      color: Color(0xFF1D9BF0),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  // ════════════════════════════ STEP 1 ════════════════════════════
  Widget _step1() => _scroll([
        const SizedBox(height: 8),
        const Center(child: AuthLogo(size: 76)),
        const SizedBox(height: 16),
        Center(
            child: Text(tr('auth.registerTitle'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        Center(
            child: Text(tr('auth.registerSubtitle1'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
        const SizedBox(height: 24),
        AuthField(
            controller: _nameCtrl,
            hint: tr('auth.fullNameHint'),
            icon: AppIcons.person_outline_rounded),
        const SizedBox(height: 14),
        AuthField(
            controller: _emailCtrl,
            hint: tr('auth.emailHint'),
            icon: AppIcons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        AuthField(
          controller: _phoneCtrl,
          hint: tr('auth.phoneHint'),
          icon: AppIcons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefix: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('🇹🇯  +992',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        AuthField(
            controller: _passCtrl,
            hint: tr('auth.passwordHint'),
            icon: AppIcons.lock_outline_rounded,
            obscure: true),
        const SizedBox(height: 14),
        AuthField(
            controller: _confirmCtrl,
            hint: tr('auth.confirmPasswordHint'),
            icon: AppIcons.lock_outline_rounded,
            obscure: true),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: _terms,
                onChanged: (v) => setState(() => _terms = v ?? false),
                activeColor: AppColors.neonBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                side: BorderSide(color: AppColors.textFaint),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('auth.termsAgree'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _errorText(),
        AuthButton(label: tr('auth.continueButton'), onTap: _submitStep1),
        _loginLink(),
      ]);

  // ════════════════════════════ STEP 2 ════════════════════════════
  Widget _step2() => _scroll([
        const SizedBox(height: 8),
        const Center(child: AuthLogo(size: 76)),
        const SizedBox(height: 16),
        Center(
            child: Text(tr('auth.usernameTitle'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        Center(
            child: Text(tr('auth.usernameSubtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
        const SizedBox(height: 24),
        AuthField(
          controller: _userCtrl,
          hint: 'nomi_hisob',
          icon: AppIcons.alternate_email_rounded,
          autofocus: false,
          onChanged: _onUsernameChanged,
          inputFormatters: [
            TextInputFormatter.withFunction((o, n) {
              final f = n.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
              return TextEditingValue(
                  text: f, selection: TextSelection.collapsed(offset: f.length));
            }),
          ],
          suffix: _checkingUsername
              ? Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.textFaint)))
              : _usernameAvailable == null
                  ? null
                  : Icon(
                      _usernameAvailable!
                          ? AppIcons.check_circle_rounded
                          : AppIcons.cancel_rounded,
                      color: _usernameAvailable!
                          ? AppColors.storyEnd
                          : Colors.redAccent,
                      size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          tr('auth.usernameHelper'),
          style: TextStyle(color: AppColors.textFaint, fontSize: 12),
        ),
        const SizedBox(height: 22),
        _errorText(),
        AuthButton(
            label: tr('auth.continueButton'), loading: _loading, onTap: _submitUsername),
        _loginLink(),
      ]);

  // ════════════════════════════ STEP 3 ════════════════════════════
  Widget _step3() => _scroll([
        const SizedBox(height: 8),
        const Center(child: AuthLogo(size: 76)),
        const SizedBox(height: 16),
        Center(
            child: Text(tr('auth.photoTitle'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        Center(
            child: Text(tr('auth.photoSubtitle'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14))),
        const SizedBox(height: 28),
        Center(
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textPrimary.withOpacity(0.05),
                border: Border.all(color: AppColors.neonBlue, width: 2),
                image: _avatar != null
                    ? DecorationImage(
                        image: FileImage(_avatar!), fit: BoxFit.cover)
                    : null,
              ),
              child: _avatar == null
                  ? Icon(AppIcons.photo_camera_rounded,
                      color: AppColors.textTertiary, size: 44)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 28),
        AuthButton(
            label: tr('auth.photoTitle'),
            showArrow: false,
            onTap: _pickAvatar),
        const SizedBox(height: 12),
        AuthOutlineButton(label: tr('auth.later'), onTap: () => _goto(3)),
        const SizedBox(height: 12),
        _errorText(),
        AuthButton(
            label: tr('auth.continueButton'), loading: _loading, onTap: _submitAvatar),
      ]);

  // ════════════════════════════ STEP 4 ════════════════════════════
  Widget _step4() => _FindFriends(onFinish: _finish);
}

// ───────────────────────── Step 4: Find Friends ──────────────────────────
class _FindFriends extends StatefulWidget {
  final VoidCallback onFinish;
  const _FindFriends({required this.onFinish});
  @override
  State<_FindFriends> createState() => _FindFriendsState();
}

class _FindFriendsState extends State<_FindFriends> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  final Set<String> _followed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final path = q.isEmpty
          ? '/users/suggestions'
          : '/search/users?q=$q';
      final res = await ApiClient.instance.get(path);
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body);
        final list = body is List
            ? body
            : (body['users'] ?? body['suggestions'] ?? body['results'] ?? [])
                as List;
        setState(() {
          _users = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String id) async {
    setState(() {
      _followed.contains(id) ? _followed.remove(id) : _followed.add(id);
    });
    try {
      await ApiClient.instance.post('/follow/$id');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AuthLogo(size: 66)),
          const SizedBox(height: 12),
          Center(
              child: Text(tr('auth.findFriendsTitle'),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold))),
          const SizedBox(height: 6),
          Center(
              child: Text(
                  tr('auth.findFriendsSubtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
          const SizedBox(height: 16),
          AuthField(
            controller: _searchCtrl,
            hint: tr('auth.searchHint'),
            icon: AppIcons.search_rounded,
            onChanged: (v) => _load(v.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.neonBlue, strokeWidth: 2))
                : _users.isEmpty
                    ? Center(
                        child: Text(tr('auth.noOneFound'),
                            style: TextStyle(color: AppColors.textFaint)))
                    : ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _tile(_users[i]),
                      ),
          ),
          const SizedBox(height: 8),
          AuthButton(
              label: tr('auth.finishButton'),
              showArrow: false,
              onTap: widget.onFinish),
          const SizedBox(height: 10),
          AuthOutlineButton(label: tr('auth.later'), onTap: widget.onFinish),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> u) {
    final id = (u['_id'] ?? u['id'] ?? '').toString();
    final username = (u['username'] ?? '').toString();
    final name = (u['fullName'] ?? u['full_name'] ?? '').toString();
    final avatar = (u['avatar'] ?? '').toString();
    final isFollowed = _followed.contains(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.card,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Icon(AppIcons.person, color: AppColors.textFaint)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleFollow(id),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: isFollowed
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.neonBlue, AppColors.storyEnd]),
                color: isFollowed ? AppColors.textPrimary.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(isFollowed ? tr('auth.followedLabel') : tr('auth.followLabel'),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
