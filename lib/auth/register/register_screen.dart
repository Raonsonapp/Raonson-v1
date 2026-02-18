import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'register_controller.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterController(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RegisterController>();
    final state = controller.state;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              Center(
                child: Image.asset(
                  'assets/icon/logo.png',
                  height: 120,
                ),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'Create Raonson Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              _field(
                label: 'Username',
                onChanged: controller.updateUsername,
              ),
              const SizedBox(height: 16),

              _field(
                label: 'Email',
                onChanged: controller.updateEmail,
              ),
              const SizedBox(height: 16),

              _field(
                label: 'Password',
                obscure: true,
                onChanged: controller.updatePassword,
              ),
              const SizedBox(height: 16),

              _field(
                label: 'Confirm Password',
                obscure: true,
                onChanged: controller.updateConfirmPassword,
              ),

              const SizedBox(height: 24),

              if (state.error != null)
                Text(
                  state.error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 16),

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
                          final ok = await controller.register();
                          if (!context.mounted) return;

                          if (ok) {
                            // ✅ Instagram-style: back to Login
                            Navigator.pop(context);
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
                          'Register',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Already have an account? Log in',
                  style: TextStyle(
                    color: Color(0xFF2EFF8A),
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
    bool obscure = false,
  }) {
    return TextField(
      obscureText: obscure,
      onChanged: onChanged,
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
