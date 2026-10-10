// lib/auth/sso/tajikshop_sign_in_screen.dart
//
// Экране, ки `raonson://sso?code=…` мекушояд (TajikShop → Raonson).
//
//   • ҳисоби пайваст / нав      → ворид мешавем (нав → «номи корбар»);
//   • почта аллакай дар Raonson → «як бор бо рамзи Raonson ворид шавед»,
//     баъди вуруд пайванд тасдиқ мешавад (худкор пайваст НАМЕШАВАД);
//   • корбар аллакай ворид аст  → пайваст кардан (бо тасдиқ, агар
//     «Пайваст кардан» аз Танзимот оғоз нашуда бошад).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/services/user_session.dart';
import '../../core/sso/tajikshop_sso.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/tajikshop_brand.dart';
import '../../settings/account_screens.dart';
import '../login/login_controller.dart';

enum _Phase { working, linkRequired, confirm, error }

class TajikshopSignInScreen extends StatefulWidget {
  const TajikshopSignInScreen({
    super.key,
    required this.code,
    this.isSignedIn,
    this.onSession,
  });

  final String code;

  /// Корбар ҳоло дар Raonson ворид аст? (пешфарз: AppState, баъди оғоз).
  final Future<bool> Function()? isSignedIn;

  /// Нигоҳ доштани сессияи нав (пешфарз: мисли /auth/login).
  final Future<void> Function(Map<String, dynamic> body)? onSession;

  @override
  State<TajikshopSignInScreen> createState() => _TajikshopSignInScreenState();
}

class _TajikshopSignInScreenState extends State<TajikshopSignInScreen> {
  _Phase _phase = _Phase.working;
  SsoResult? _result;
  bool _busy = false;

  TajikshopSso get _sso => TajikshopSso.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<bool> _defaultSignedIn() async {
    AppState? st;
    try {
      st = context.read<AppState>();
    } catch (_) {}
    if (st == null) return ApiClient.instance.authToken != null;
    final s = st;
    if (!s.isInitialized) {
      final done = Completer<void>();
      void l() {
        if (s.isInitialized && !done.isCompleted) done.complete();
      }
      s.addListener(l);
      l();
      await done.future
          .timeout(const Duration(seconds: 10), onTimeout: () {});
      s.removeListener(l);
    }
    return s.isAuthenticated;
  }

  Future<void> _defaultSession(Map<String, dynamic> body) async {
    await persistLoginResponse(body);
    if (!mounted) return;
    try {
      context.read<AppState>().login();
    } catch (_) {}
  }

  Future<void> _run() async {
    if (_sso.wasHandled(widget.code)) {
      _leave();
      return;
    }
    _sso.markHandled(widget.code);
    final signedIn = await (widget.isSignedIn ?? _defaultSignedIn)();
    final intent = signedIn && await _sso.consumeLinkIntent();
    final r = await _sso.repo.signIn(widget.code, link: intent);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    switch (r.outcome) {
      case SsoOutcome.signedIn:
        await (widget.onSession ?? _defaultSession)(r.body);
        if (!mounted) return;
        if (signedIn) {
          // Ҳамон ҳисоб аллакай пайваст буд — танҳо бармегардем.
          _leave();
          return;
        }
        _goHome(setup: r.needsProfileSetup);
        return;
      case SsoOutcome.linked:
        _sso.linkChanged.value++;
        messenger?.showSnackBar(SnackBar(content: Text(tr('sso.linked'))));
        _leave();
        return;
      case SsoOutcome.confirmLink:
      case SsoOutcome.linkRequired:
      case SsoOutcome.failed:
        setState(() {
          _result = r;
          _phase = switch (r.outcome) {
            SsoOutcome.confirmLink => _Phase.confirm,
            SsoOutcome.linkRequired => _Phase.linkRequired,
            _ => _Phase.error,
          };
        });
    }
  }

  void _goHome({bool setup = false}) {
    final nav = Navigator.of(context);
    nav.pushNamedAndRemoveUntil('/', (r) => false);
    if (setup) {
      nav.push(MaterialPageRoute(
          builder: (_) =>
              ChangeUsernameScreen(intro: tr('sso.chooseUsernameIntro'))));
    }
  }

  void _leave() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  /// «Ворид шудан ба Raonson» — пайванд баъди вуруд тасдиқ мешавад.
  void _loginToConfirm() {
    final r = _result!;
    _sso.setPending(r.pendingToken, r.maskedEmail, r.expiresIn);
    final nav = Navigator.of(context);
    nav.pushNamedAndRemoveUntil('/', (r) => false);
    // Агар корбар дар ин миён ворид бошад, экрани «/» — хона аст;
    // вагарна экрани вуруд, ки банери пайвандро нишон медиҳад.
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await _sso.repo.confirmLink(_result!.pendingToken);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.outcome == SsoOutcome.linked) {
      _sso.linkChanged.value++;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(tr('sso.linked'))));
      _leave();
    } else {
      setState(() {
        _result = r;
        _phase = _Phase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: TajikshopBrand.logo(size: 20),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String s) => Text(s,
      textAlign: TextAlign.center,
      style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800));

  Widget _text(String s) => Text(s,
      textAlign: TextAlign.center,
      style: TextStyle(
          color: AppColors.textSecondary, fontSize: 14.5, height: 1.4));

  Widget _primary(String label, VoidCallback? onTap, {Key? key}) =>
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          key: key,
          style: ElevatedButton.styleFrom(
              backgroundColor: TajikshopBrand.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: onTap,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _secondary(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(label,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
      );

  Widget _body() {
    switch (_phase) {
      case _Phase.working:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: TajikshopBrand.primary),
          const SizedBox(height: 20),
          _text(tr('sso.signingIn')),
        ]);
      case _Phase.linkRequired:
        final r = _result!;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.link_rounded, size: 48, color: TajikshopBrand.primary),
          const SizedBox(height: 14),
          _title(tr('sso.linkRequiredTitle')),
          const SizedBox(height: 10),
          _text(tr('sso.linkRequiredBody', {'email': r.maskedEmail})),
          const SizedBox(height: 24),
          _primary(tr('sso.loginToConfirm'), _loginToConfirm,
              key: const Key('sso-login-to-confirm')),
          const SizedBox(height: 6),
          _secondary(tr('sso.notNow'), _leave),
        ]);
      case _Phase.confirm:
        final a = _result!.account;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.link_rounded, size: 48, color: TajikshopBrand.primary),
          const SizedBox(height: 14),
          _title(tr('sso.confirmTitle')),
          const SizedBox(height: 10),
          _text(tr('sso.confirmBody', {
            'name': a.name,
            'email': a.email,
            'username': UserSession.username ?? '',
          })),
          const SizedBox(height: 24),
          _primary(tr('sso.link'), _busy ? null : _confirm,
              key: const Key('sso-confirm-link')),
          const SizedBox(height: 6),
          _secondary(tr('sso.notNow'), _leave),
        ]);
      case _Phase.error:
        final r = _result!;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(AppIcons.error_outline_rounded,
              size: 48, color: Colors.redAccent),
          const SizedBox(height: 14),
          _title(tr('sso.error')),
          const SizedBox(height: 10),
          _text(r.message),
          if (r.code == 'invalid_code' || r.code == 'link_expired') ...[
            const SizedBox(height: 6),
            _text(tr('sso.retryFromTs')),
          ],
          const SizedBox(height: 24),
          _primary(tr('sso.close'), _leave),
        ]);
    }
  }
}

/// «Бо TajikShop ворид шавед» дар экрани вуруд.
///
/// Raonson худаш коди TajikShop гирифта наметавонад (корбар ҳанӯз дар
/// Raonson ворид нест) — TajikShop кушода мешавад, корбар дар он ворид
/// шуда «Ба Raonson гузаред»-ро мезанад ва TajikShop ӯро бо
/// `raonson://sso?code=…` бармегардонад.
Future<void> showTajikshopSignInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TajikshopBrand.logo(size: 22),
          const SizedBox(height: 14),
          Text(tr('sso.signInExplainTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(tr('sso.signInExplain'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              key: const Key('sso-open-tajikshop'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: TajikshopBrand.primary,
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(sheet);
                TajikshopSso.instance.openPlain();
              },
              child: Text(tr('sso.openTajikshop')),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(sheet),
            child: Text(tr('sso.cancel'),
                style: TextStyle(color: AppColors.textTertiary)),
          ),
        ]),
      ),
    ),
  );
}

/// Банери экрани вуруд: «баъди вуруд TajikShop пайваст мешавад».
class TajikshopPendingBanner extends StatelessWidget {
  const TajikshopPendingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PendingTajikshopLink?>(
      valueListenable: TajikshopSso.instance.pendingLink,
      builder: (_, p, __) {
        if (p == null || p.expired) return const SizedBox.shrink();
        return Container(
          key: const Key('sso-pending-banner'),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            color: TajikshopBrand.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: TajikshopBrand.primary.withOpacity(0.35)),
          ),
          child: Row(children: [
            const Icon(AppIcons.link_rounded, color: TajikshopBrand.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr('sso.pendingBanner', {'email': p.maskedEmail}),
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13, height: 1.35)),
            ),
            IconButton(
              tooltip: tr('sso.cancel'),
              icon: Icon(AppIcons.close_rounded,
                  color: AppColors.textTertiary, size: 20),
              onPressed: TajikshopSso.instance.clearPending,
            ),
          ]),
        );
      },
    );
  }
}
