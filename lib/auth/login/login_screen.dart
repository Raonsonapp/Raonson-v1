import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import 'login_controller.dart';

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

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LoginController>();
    final state = ctrl.state;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),

              // Logo
              Center(
                child: Image.asset('assets/icon/logo.png', height: 100),
              ),
              const SizedBox(height: 16),

              // App name
              const Center(
                child: Text(
                  'Raonson',
                  style: TextStyle(
                    fontFamily: 'RaonsonFont',
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: AppColors.neonBlue,
                        blurRadius: 20,
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Email field
              _Field(
                label: 'Email',
                onChanged: ctrl.updateEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password field
              _Field(
                label: 'Password',
                onChanged: ctrl.updatePassword,
                obscure: true,
              ),
              const SizedBox(height: 8),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, AppRoutes.forgotPassword),
                  child: const Text('Forgot password?',
                      style: TextStyle(color: AppColors.neonBlue)),
                ),
              ),
              const SizedBox(height: 8),

              // Error
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              // Login button
              _NeonButton(
                label: 'Log In',
                isLoading: state.isLoading,
                enabled: state.canSubmit,
                onTap: () async {
                  final ok = await ctrl.login();
                  if (!context.mounted) return;
                  if (ok) {
                    context.read<AppState>().login();
                  }
                },
              ),

              const SizedBox(height: 32),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),

              // Register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Colors.white54)),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.register),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.onChanged,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _NeonButton({
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: enabled ? AppColors.neonBlue : AppColors.surface,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
