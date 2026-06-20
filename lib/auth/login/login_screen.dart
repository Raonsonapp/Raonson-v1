import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_routes.dart';
import '../widgets/auth_kit.dart';
import 'login_controller.dart';
import '../../app/app_theme.dart';

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
    if (ok) context.read<AppState>().login();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LoginController>();
    final state = ctrl.state;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                    alignment: Alignment.topCenter, child: LangChip()),
                const SizedBox(height: 28),
                const Center(child: AuthLogo(size: 92)),
                const SizedBox(height: 28),
                Center(
                  child: Text('Хуш омадед!',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Барои идомаи кор ба ҳисоби худ ворид шавед',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                ),
                const SizedBox(height: 28),

                AuthField(
                  controller: _idCtrl,
                  hint: 'Телефон, номи корбар ё почта',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _pwCtrl,
                  hint: 'Рамз',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
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
                    child: const Text('Рамзро фаромӯш кардед?',
                        style: TextStyle(
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
                  label: 'Ворид шудан',
                  loading: state.isLoading,
                  onTap: () => _submit(ctrl),
                ),
                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ҳисоб надоред? ',
                        style:
                            TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      child: const Text('Сабти ном кунед',
                          style: TextStyle(
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
    );
  }
}
