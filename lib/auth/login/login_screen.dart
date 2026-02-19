import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/app_routes.dart';
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
    final controller = context.watch<LoginController>();
    final state = controller.state;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // LOGO
              Center(
                child: Image.asset(
                  'assets/icon/logo.png',
                  height: 110,
                ),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'Log in to Raonson',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // EMAIL
              _field(
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: controller.updateEmail,
              ),

              const SizedBox(height: 20),

              // PASSWORD
              _field(
                label: 'Password',
                obscure: true,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onChanged: controller.updatePassword,
              ),

              const SizedBox(height: 24),

              // ERROR
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),

              // LOGIN BUTTON
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EFF8A),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: state.canSubmit
                      ? () async {
                          final success = await controller.login();
                          if (!context.mounted) return;

                          if (success) {
                            context.read<AppState>().login();
                          }
                        }
                      : null,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // GO TO REGISTER
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.register);
                },
                child: const Text(
                  'Create new account',
                  style: TextStyle(
                    color: Color(0xFF2EFF8A),
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    TextInputAction? textInputAction,
    bool obscure = false,
  }) {
    return TextField(
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onChanged: (value) => onChanged(value.trim()),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFF2EFF8A),
            width: 2,
          ),
        ),
      ),
    );
  }
}
