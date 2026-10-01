// lib/auth/password/recovery_help_screen.dart
//
// «Кӯмак лозим» — вақте корбар ба почта ва телефони ҳисоб дастрасӣ
// надорад (ё ҳисоб умуман почта/телефон надорад). Дархост ба
// маъмурият меравад; баъди тасдиқ рамзи якдафъаина (24 соат) ба почтаи
// тамос меояд ва корбар онро дар «Рамзи барқарорсозӣ дорам» ворид
// мекунад. Маъмурият паролро намебинад ва гузошта наметавонад.
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import 'recovery_repository.dart';
import 'recovery_widgets.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$');

AppBar _bar(String title) => AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      title: Text(title,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600)),
    );

class RecoveryHelpScreen extends StatefulWidget {
  final RecoveryRepository? repository;
  final String identifier;
  final PersistLogin? persist;
  final LoggedInCallback? onLoggedIn;
  const RecoveryHelpScreen({
    super.key,
    this.repository,
    this.identifier = '',
    this.persist,
    this.onLoggedIn,
  });

  @override
  State<RecoveryHelpScreen> createState() => _RecoveryHelpScreenState();
}

class _RecoveryHelpScreenState extends State<RecoveryHelpScreen> {
  late final RecoveryRepository _repo =
      widget.repository ?? RecoveryRepository();
  late final _idCtrl = TextEditingController(text: widget.identifier);
  final _nameCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;
  bool _alreadyPending = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _mailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final mail = _mailCtrl.text.trim();
    String? err;
    if (id.isEmpty) {
      err = tr('recover.findSubtitle');
    } else if (name.runes.length < 2) {
      err = tr('recover.help.fullName');
    } else if (!_emailRe.hasMatch(mail)) {
      err = tr('recover.help.contactEmail');
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await _repo.requestHelp(
          identifier: id,
          contactEmail: mail,
          fullName: name,
          message: _msgCtrl.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _alreadyPending = pending;
      });
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr('recover.err.generic'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(tr('recover.help.title')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [_sent ? _sentView() : _formView()],
        ),
      ),
    );
  }

  Widget _formView() {
    final style = TextStyle(color: AppColors.textPrimary);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RecoveryHeader(
          icon: AppIcons.verified_user_outlined,
          title: tr('recover.help.title'),
          subtitle: tr('recover.help.subtitle')),
      TextField(
          key: const Key('help-identifier'),
          controller: _idCtrl,
          style: style,
          decoration: recoveryInput(tr('recover.idHint'),
              icon: AppIcons.person_outline_rounded)),
      const SizedBox(height: 12),
      TextField(
          key: const Key('help-name'),
          controller: _nameCtrl,
          style: style,
          textCapitalization: TextCapitalization.words,
          maxLength: 100,
          decoration: recoveryInput(tr('recover.help.fullName'),
              icon: AppIcons.person_rounded)),
      const SizedBox(height: 12),
      TextField(
          key: const Key('help-email'),
          controller: _mailCtrl,
          style: style,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: recoveryInput(tr('recover.help.contactEmail'),
              icon: AppIcons.email_outlined)),
      const SizedBox(height: 12),
      TextField(
          key: const Key('help-message'),
          controller: _msgCtrl,
          style: style,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          decoration: recoveryInput(tr('recover.help.message'))),
      RecoveryError(_error),
      const SizedBox(height: 20),
      RecoveryButton(
          key: const Key('help-submit'),
          label: tr('recover.help.submit'),
          loading: _loading,
          onPressed: _submit),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => RecoveryCodeScreen(
                    repository: _repo,
                    persist: widget.persist,
                    onLoggedIn: widget.onLoggedIn))),
        child: Text(tr('recover.haveCode'),
            style: TextStyle(color: AppColors.neonBlue, fontSize: 13.5)),
      ),
    ]);
  }

  Widget _sentView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 32),
      const Center(
          child: Icon(AppIcons.mark_email_read_outlined,
              color: Color(0xFF34C759), size: 76)),
      const SizedBox(height: 18),
      Text(tr('recover.help.sentTitle'),
          key: const Key('help-sent'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (_alreadyPending)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(tr('recover.help.pending'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
      Text(tr('recover.help.sentBody', {'email': _mailCtrl.text.trim()}),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textTertiary, fontSize: 14, height: 1.4)),
      const SizedBox(height: 26),
      RecoveryButton(
        label: tr('recover.haveCode'),
        onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => RecoveryCodeScreen(
                    repository: _repo,
                    persist: widget.persist,
                    onLoggedIn: widget.onLoggedIn))),
      ),
    ]);
  }
}

/// «Рамзи барқарорсозӣ дорам»: рамзи 12-аломата аз почтаи тамос
/// (баъди тасдиқи маъмурият) + рамзи нав.
class RecoveryCodeScreen extends StatefulWidget {
  final RecoveryRepository? repository;
  final PersistLogin? persist;
  final LoggedInCallback? onLoggedIn;
  const RecoveryCodeScreen(
      {super.key, this.repository, this.persist, this.onLoggedIn});

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  late final RecoveryRepository _repo =
      widget.repository ?? RecoveryRepository();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String password) async {
    final code = _codeCtrl.text.trim();
    if (code.replaceAll(RegExp(r'[\s-]'), '').length < 12) {
      setState(() => _error = tr('recover.code.subtitle'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.reset(code, password);
      if (!mounted) return;
      await finishRecoveryLogin(context, data,
          persist: widget.persist, onLoggedIn: widget.onLoggedIn);
      if (mounted) setState(() => _done = true);
    } on RecoveryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr('recover.err.generic'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _bar(tr('recover.code.title')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            if (_done)
              RecoveryDoneView(onContinue: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              })
            else ...[
              RecoveryHeader(
                  icon: AppIcons.lock_open_rounded,
                  title: tr('recover.code.title'),
                  subtitle: tr('recover.code.subtitle')),
              TextField(
                key: const Key('recovery-code'),
                controller: _codeCtrl,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                maxLength: 16,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600),
                decoration: recoveryInput('XXXX-XXXX-XXXX',
                    icon: AppIcons.lock_outline_rounded),
              ),
              const SizedBox(height: 12),
              NewPasswordForm(
                  loading: _loading, error: _error, onSubmit: _submit),
            ],
          ],
        ),
      ),
    );
  }
}
