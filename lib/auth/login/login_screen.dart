import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_settings.dart';
import '../../app/app_routes.dart';
import '../widgets/auth_kit.dart';
import 'login_controller.dart';
import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginController ctrl) async {
    ctrl.updateEmail(_idCtrl.text.trim());
    ctrl.updatePassword(_pwCtrl.text);
    final ok = await ctrl.login();
    if (!mounted) return;
    if (ok) {
      context.read<AppState>().login();
      // Агар ин экран аз дохили барнома кушода шуда бошад (илова кардани
      // аккаунт), онро мебандем — вагарна корбар дар экрани login мемонад.
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LoginController>();
    final state = ctrl.state;

    // ✅ Listen to AppSettingsState so tr() re-runs when the language flips.
    return AnimatedBuilder(
      animation: AppSettingsState.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.bg,
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Тугмаи «ба ақиб» — танҳо вақте экрани login аз дохили
                // барнома кушода шудааст (илова кардани аккаунт).
                if (Navigator.of(context).canPop())
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(AppIcons.arrow_back_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                const Align(
                    alignment: Alignment.topCenter, child: LangChip()),
                const SizedBox(height: 28),
                const Center(child: AuthLogo(size: 92)),
                const SizedBox(height: 28),
                Center(
                  child: Text(tr('auth.welcome'),
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(tr('auth.loginSubtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                ),
                const SizedBox(height: 28),

                AuthField(
                  controller: _idCtrl,
                  hint: tr('auth.idHint'),
                  icon: AppIcons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _pwCtrl,
                  hint: tr('auth.passwordHint'),
                  icon: AppIcons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure
                            ? AppIcons.visibility_off_rounded
                            : AppIcons.visibility_rounded,
                        color: AppColors.textFaint, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.forgotPassword),
                    child: Text(tr('auth.forgotPassword'),
                        style: const TextStyle(
                            color: Color(0xFF1D9BF0), fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),

                if (state.error != null) ...[
                  Text(state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                ],

                AuthButton(
                  label: tr('auth.loginButton'),
                  loading: state.isLoading,
                  onTap: () => _submit(ctrl),
                ),
                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tr('auth.noAccount'),
                        style:
                            TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      child: Text(tr('auth.registerLink'),
                          style: const TextStyle(
                              color: Color(0xFF1D9BF0),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
