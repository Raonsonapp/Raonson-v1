// lib/auth/password/recovery_widgets.dart
//
// Қисмҳои умумии экранҳои барқарорсозӣ: 6 хонаи рамз, формаи рамзи нав
// бо маслиҳатҳои қувват ва тугмаи асосӣ.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import '../login/login_controller.dart';
import 'recovery_repository.dart';

/// Нигоҳ доштани token-ҳо (дар тест иваз мешавад).
typedef PersistLogin = Future<void> Function(Map<String, dynamic> data);

/// Баъди нигоҳ доштани token-ҳо: барнома ба ҳолати «ворид шуд» мегузарад.
typedef LoggedInCallback = void Function(BuildContext context);

void defaultLoggedIn(BuildContext context) {
  try {
    context.read<AppState>().login();
  } catch (_) {
    // Бе AppState (масалан дар тест) — танҳо token-ҳо нигоҳ дошта шуданд.
  }
}

const recoveryErrorColor = Color(0xFFFF3B30);

InputDecoration recoveryInput(String hint, {Widget? suffix, IconData? icon}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textFaint),
      filled: true,
      fillColor: AppColors.card,
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.textFaint, size: 20),
      suffixIcon: suffix,
      counterText: '',
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

class RecoveryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const RecoveryButton(
      {super.key, required this.label, this.loading = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.neonBlue.withOpacity(0.45),
          disabledForegroundColor: Colors.white70,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class RecoveryError extends StatelessWidget {
  final String? text;
  const RecoveryError(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(AppIcons.error_outline_rounded,
            color: recoveryErrorColor, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text!,
              key: const Key('recover-error'),
              style: const TextStyle(color: recoveryErrorColor, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// 6 хона барои рамз. Як майдони пинҳон зери хонаҳо — нусхагузорӣ (paste)
/// ва автопуркунии SMS кор мекунад.
class CodeBoxesField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final bool hasError;
  const CodeBoxesField({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  State<CodeBoxesField> createState() => _CodeBoxesFieldState();
}

class _CodeBoxesFieldState extends State<CodeBoxesField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final filled = i < text.length;
            final active = i == text.length && _focus.hasFocus;
            return Container(
              width: 46,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.hasError
                      ? recoveryErrorColor
                      : active
                          ? AppColors.neonBlue
                          : AppColors.divider,
                  width: active || widget.hasError ? 1.6 : 1,
                ),
              ),
              child: Text(filled ? text[i] : '',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
            );
          }),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: const Key('recover-code-field'),
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: true,
              showCursor: false,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(counterText: ''),
              onChanged: (v) {
                if (v.length == 6) widget.onCompleted(v);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

/// Рамзи нав + такрор бо маслиҳатҳои қувват.
class NewPasswordForm extends StatefulWidget {
  final bool loading;
  final String? error;
  final Future<void> Function(String password) onSubmit;
  const NewPasswordForm(
      {super.key, required this.onSubmit, this.loading = false, this.error});

  @override
  State<NewPasswordForm> createState() => _NewPasswordFormState();
}

class _NewPasswordFormState extends State<NewPasswordForm> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _submit() {
    final err = newPasswordError(_pw.text, _pw2.text);
    setState(() => _localError = err);
    if (err == null) widget.onSubmit(_pw.text);
  }

  Widget _rule(bool ok, String text, {bool optional = false}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Icon(ok ? AppIcons.check_circle_rounded : AppIcons.radio_button_unchecked,
              size: 16,
              color: ok
                  ? const Color(0xFF34C759)
                  : (optional ? AppColors.textFaint : AppColors.textTertiary)),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: ok ? AppColors.textSecondary : AppColors.textTertiary,
                  fontSize: 12.5)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final check = checkPassword(_pw.text);
    final colors = [
      recoveryErrorColor,
      const Color(0xFFFF9500),
      const Color(0xFFFFCC00),
      const Color(0xFF34C759)
    ];
    final eye = IconButton(
      icon: Icon(
          _obscure ? AppIcons.visibility_off_rounded : AppIcons.visibility_rounded,
          color: AppColors.textFaint,
          size: 20),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        key: const Key('recover-new-password'),
        controller: _pw,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.newPassword],
        style: TextStyle(color: AppColors.textPrimary),
        onChanged: (_) => setState(() => _localError = null),
        decoration: recoveryInput(tr('recover.newPassword'),
            suffix: eye, icon: AppIcons.lock_outline_rounded),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('recover-confirm-password'),
        controller: _pw2,
        obscureText: _obscure,
        style: TextStyle(color: AppColors.textPrimary),
        onChanged: (_) => setState(() => _localError = null),
        onSubmitted: (_) => _submit(),
        decoration: recoveryInput(tr('recover.confirmPassword'),
            icon: AppIcons.lock_outline_rounded),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _pw.text.isEmpty ? 0 : (check.score + 1) / 4,
          minHeight: 4,
          backgroundColor: AppColors.divider,
          color: colors[check.score],
        ),
      ),
      _rule(check.longEnough, tr('recover.rule.length')),
      _rule(check.lettersAndDigits, tr('recover.rule.mix')),
      _rule(check.hasSymbol, tr('recover.rule.symbol'), optional: true),
      RecoveryError(_localError ?? widget.error),
      const SizedBox(height: 20),
      RecoveryButton(
        key: const Key('recover-save'),
        label: tr('recover.save'),
        loading: widget.loading,
        onPressed: _submit,
      ),
    ]);
  }
}

/// Экрани «Рамз иваз шуд» — корбар аллакай ворид шудааст.
class RecoveryDoneView extends StatelessWidget {
  final VoidCallback onContinue;
  const RecoveryDoneView({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 32),
      const Center(
        child: Icon(AppIcons.check_circle_rounded,
            color: Color(0xFF34C759), size: 84),
      ),
      const SizedBox(height: 20),
      Text(tr('recover.doneTitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text(tr('recover.doneBody'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textTertiary, fontSize: 14, height: 1.4)),
      const SizedBox(height: 28),
      RecoveryButton(
          key: const Key('recover-continue'),
          label: tr('recover.continue'),
          onPressed: onContinue),
    ]);
  }
}

/// Рамзи нав → нигоҳ доштани token-ҳо → «ворид шуд».
Future<void> finishRecoveryLogin(
  BuildContext context,
  Map<String, dynamic> data, {
  PersistLogin? persist,
  LoggedInCallback? onLoggedIn,
}) async {
  await (persist ?? persistLoginResponse)(data);
  if (!context.mounted) return;
  (onLoggedIn ?? defaultLoggedIn)(context);
}

/// Сарлавҳа ва зерсарлавҳаи ҳар қадам.
class RecoveryHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const RecoveryHeader(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 8),
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textFaint, width: 2),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 38),
      ),
      const SizedBox(height: 20),
      Text(title,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textTertiary, fontSize: 13.5, height: 1.4)),
      const SizedBox(height: 22),
    ]);
  }
}
