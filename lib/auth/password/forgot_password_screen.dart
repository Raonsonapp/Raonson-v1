// lib/auth/password/forgot_password_screen.dart
//
// «Рамзро фаромӯш кардед?» — мисли Instagram, қадам ба қадам:
//
//   1. Ҳисоби худро ёбед: номи корбар, почта ё телефон.
//   2. «Ин шумоед?»: акс, номи пӯшида ва роҳҳое, ки рамз ҲОЗИР расида
//      метавонад (почта; SMS/Telegram/WhatsApp — танҳо агар фаъол бошад).
//   3. 6 хонаи рамз, вақтшумор барои «рамзи нав».
//   4. Рамзи нав + такрор бо маслиҳатҳои қувват.
//   5. Тайёр — корбар аллакай ворид шудааст (ҳамаи дастгоҳҳои дигар
//      хориҷ карда шуданд).
//
// Пеш корбар канали фиристодани рамзро кӯр-кӯрона интихоб мекард
// (Telegram ё Email), ва сервер ҳисобро бо `OR` меҷуст — рамз метавонист
// ба ҳисоби каси дигар равад.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import 'recovery_help_screen.dart';
import 'recovery_repository.dart';
import 'recovery_widgets.dart';

enum RecoveryStep { identify, confirm, code, password, done }

class ForgotPasswordScreen extends StatefulWidget {
  final RecoveryRepository? repository;
  final PersistLogin? persist;
  final LoggedInCallback? onLoggedIn;
  final String initialIdentifier;

  const ForgotPasswordScreen({
    super.key,
    this.repository,
    this.persist,
    this.onLoggedIn,
    this.initialIdentifier = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final RecoveryRepository _repo =
      widget.repository ?? RecoveryRepository();
  late final _idCtrl = TextEditingController(text: widget.initialIdentifier);
  final _codeCtrl = TextEditingController();

  RecoveryStep _step = RecoveryStep.identify;
  bool _loading = false;
  String? _error;
  bool _codeError = false;

  RecoveryLookup? _account;
  String _identifier = '';
  String? _channel;
  RecoverySent? _sent;
  String? _resetToken;

  Timer? _timer;
  int _resendLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _idCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _go(RecoveryStep s) => setState(() {
        _step = s;
        _error = null;
        _codeError = false;
      });

  Future<void> _run(Future<void> Function() body) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await body();
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr('recover.err.generic'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 1. Ёфтан ─────────────────────────────────────────────────────
  Future<void> _lookup() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _error = tr('recover.findSubtitle'));
      return;
    }
    await _run(() async {
      final r = await _repo.lookup(id);
      if (!mounted) return;
      if (r.needUsername) {
        setState(() => _error = tr('recover.needUsername'));
        return;
      }
      if (!r.found) {
        setState(() => _error = tr('recover.notFound'));
        return;
      }
      _identifier = id;
      _account = r;
      _channel = r.channels.isNotEmpty ? r.channels.first.type : null;
      _go(RecoveryStep.confirm);
    });
  }

  // ── 2–3. Фиристодан ва рамз ──────────────────────────────────────
  Future<void> _send() async {
    final ch = _channel;
    if (ch == null) return;
    await _run(() async {
      final sent = await _repo.send(_identifier, ch);
      if (!mounted) return;
      _sent = sent;
      _codeCtrl.clear();
      _startResendTimer(sent.resendIn);
      if (_step != RecoveryStep.code) _go(RecoveryStep.code);
    });
  }

  Future<void> _resend() async {
    final ch = _channel;
    if (ch == null || _resendLeft > 0) return;
    await _run(() async {
      try {
        final sent = await _repo.send(_identifier, ch);
        _sent = sent;
        _codeCtrl.clear();
        _codeError = false;
        _startResendTimer(sent.resendIn);
      } on RecoveryException catch (e) {
        if (e.code == 'cooldown' && e.retryAfter != null) {
          _startResendTimer(e.retryAfter!);
        }
        rethrow;
      }
    });
  }

  void _startResendTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendLeft = (_resendLeft - 1).clamp(0, 9999));
      if (_resendLeft == 0) t.cancel();
    });
  }

  Future<void> _verify([String? value]) async {
    final code = (value ?? _codeCtrl.text).trim();
    if (code.length != 6) {
      setState(() => _error = tr('recover.err.wrongCode'));
      return;
    }
    await _run(() async {
      try {
        _resetToken = await _repo.verify(_identifier, code);
        if (mounted) _go(RecoveryStep.password);
      } on RecoveryException catch (e) {
        _codeCtrl.clear();
        _codeError = true;
        // Рамз гузашт ё қуфл шуд — рамзи нав бояд фиристод.
        if (e.code == 'expired' || e.code == 'locked') _resendLeft = 0;
        rethrow;
      }
    });
  }

  // ── 4. Рамзи нав ─────────────────────────────────────────────────
  Future<void> _reset(String password) async {
    final token = _resetToken;
    if (token == null) return _go(RecoveryStep.identify);
    await _run(() async {
      try {
        final data = await _repo.reset(token, password);
        if (!mounted) return;
        await finishRecoveryLogin(context, data,
            persist: widget.persist, onLoggedIn: widget.onLoggedIn);
        _timer?.cancel();
        if (mounted) _go(RecoveryStep.done);
      } on RecoveryException catch (e) {
        if (e.code == 'invalid_token') {
          // Token сӯхт ё мӯҳлаташ гузашт — аз нав.
          _resetToken = null;
          _step = RecoveryStep.identify;
        }
        rethrow;
      }
    });
  }

  void _openHelp() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecoveryHelpScreen(
                  repository: _repo,
                  identifier: _identifier.isNotEmpty
                      ? _identifier
                      : _idCtrl.text.trim(),
                  persist: widget.persist,
                  onLoggedIn: widget.onLoggedIn,
                )));
  }

  void _openCodeScreen() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecoveryCodeScreen(
                repository: _repo,
                persist: widget.persist,
                onLoggedIn: widget.onLoggedIn)));
  }

  bool _onBack() {
    switch (_step) {
      case RecoveryStep.confirm:
        _go(RecoveryStep.identify);
        return false;
      case RecoveryStep.code:
        _timer?.cancel();
        _go(RecoveryStep.confirm);
        return false;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == RecoveryStep.identify ||
          _step == RecoveryStep.password ||
          _step == RecoveryStep.done,
      onPopInvoked: (didPop) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(tr('recover.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [_body()],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case RecoveryStep.identify:
        return _identifyView();
      case RecoveryStep.confirm:
        return _confirmView();
      case RecoveryStep.code:
        return _codeView();
      case RecoveryStep.password:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RecoveryHeader(
              icon: AppIcons.lock_open_rounded,
              title: tr('recover.newPasswordTitle'),
              subtitle: tr('recover.newPasswordSubtitle')),
          NewPasswordForm(
              loading: _loading, error: _error, onSubmit: _reset),
        ]);
      case RecoveryStep.done:
        return RecoveryDoneView(onContinue: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.popUntil((r) => r.isFirst);
          }
        });
    }
  }

  Widget _identifyView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RecoveryHeader(
          icon: AppIcons.lock_outline_rounded,
          title: tr('recover.findTitle'),
          subtitle: tr('recover.findSubtitle')),
      TextField(
        key: const Key('recover-identifier'),
        controller: _idCtrl,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _lookup(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        style: TextStyle(color: AppColors.textPrimary),
        decoration: recoveryInput(tr('recover.idHint'),
            icon: AppIcons.person_outline_rounded),
      ),
      RecoveryError(_error),
      const SizedBox(height: 20),
      RecoveryButton(
          key: const Key('recover-search'),
          label: tr('recover.search'),
          loading: _loading,
          onPressed: _lookup),
      const SizedBox(height: 18),
      TextButton(
        key: const Key('recover-have-code'),
        onPressed: _openCodeScreen,
        child: Text(tr('recover.haveCode'),
            style: TextStyle(color: AppColors.neonBlue, fontSize: 13.5)),
      ),
      TextButton(
        onPressed: _openHelp,
        child: Text(tr('recover.getHelp'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      ),
    ]);
  }

  IconData _channelIcon(String type) {
    switch (type) {
      case 'email':
        return AppIcons.email_outlined;
      case 'telegram':
        return AppIcons.send_rounded;
      case 'whatsapp':
        return AppIcons.chat_bubble_outline_rounded;
      default:
        return AppIcons.phone_outlined;
    }
  }

  Widget _confirmView() {
    final acc = _account!;
    final hasChannels = acc.channels.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      Text(tr('recover.isThisYou'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.divider,
            backgroundImage:
                acc.avatar.startsWith('http') ? NetworkImage(acc.avatar) : null,
            child: acc.avatar.startsWith('http')
                ? null
                : Icon(AppIcons.person_rounded,
                    color: AppColors.textTertiary, size: 40),
          ),
          const SizedBox(height: 10),
          Text(acc.maskedUsername,
              key: const Key('recover-masked-username'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 20),
      if (hasChannels) ...[
        Text(tr('recover.chooseChannel'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        const SizedBox(height: 8),
        ...acc.channels.map((c) {
          final selected = _channel == c.type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              key: Key('recover-channel-${c.type}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _channel = c.type),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.neonBlue.withOpacity(0.12)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? AppColors.neonBlue : AppColors.divider,
                      width: selected ? 1.5 : 1),
                ),
                child: Row(children: [
                  Icon(_channelIcon(c.type),
                      color: selected
                          ? AppColors.neonBlue
                          : AppColors.textTertiary,
                      size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(c.to,
                              style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12.5)),
                        ]),
                  ),
                  Icon(
                      selected
                          ? AppIcons.radio_button_checked
                          : AppIcons.radio_button_unchecked,
                      color: selected
                          ? AppColors.neonBlue
                          : AppColors.textFaint,
                      size: 20),
                ]),
              ),
            ),
          );
        }),
        RecoveryError(_error),
        const SizedBox(height: 12),
        RecoveryButton(
            key: const Key('recover-send'),
            label: tr('recover.sendCode'),
            loading: _loading,
            onPressed: _send),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(AppIcons.info_outline_rounded,
                color: Color(0xFFFF9500), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr('recover.noChannel'),
                  key: const Key('recover-no-channel'),
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13.5)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        RecoveryButton(
            key: const Key('recover-help'),
            label: tr('recover.help.title'),
            onPressed: _openHelp),
      ],
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => _go(RecoveryStep.identify),
        child: Text(tr('recover.notMe'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13.5)),
      ),
      if (hasChannels)
        TextButton(
          onPressed: _openHelp,
          child: Text(tr('recover.getHelp'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neonBlue, fontSize: 13)),
        ),
    ]);
  }

  Widget _codeView() {
    final to = _sent?.to ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RecoveryHeader(
          icon: AppIcons.mark_email_read_outlined,
          title: tr('recover.enterCode'),
          subtitle: tr('recover.codeSentTo', {'to': to})),
      CodeBoxesField(
        controller: _codeCtrl,
        enabled: !_loading,
        hasError: _codeError,
        onCompleted: _verify,
      ),
      RecoveryError(_error),
      const SizedBox(height: 20),
      RecoveryButton(
          key: const Key('recover-verify'),
          label: tr('recover.verify'),
          loading: _loading,
          onPressed: () => _verify()),
      const SizedBox(height: 10),
      Center(
        child: _resendLeft > 0
            ? Text(tr('recover.resendIn', {'s': _resendLeft}),
                key: const Key('recover-resend-timer'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 13))
            : TextButton(
                key: const Key('recover-resend'),
                onPressed: _loading ? null : _resend,
                child: Text(tr('recover.resend'),
                    style: TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.w600)),
              ),
      ),
    ]);
  }
}
