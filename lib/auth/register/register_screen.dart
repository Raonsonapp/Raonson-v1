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
      body: SafeArea(
        child: SingleChildScrollView( // ✅ МУҲИМ
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ================= LOGO =================
              Image.asset(
                'assets/icon/logo.png',
                width: 120,
                height: 120,
              ),

              const SizedBox(height: 24),

              const Text(
                'Create Raonson Account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ================= USERNAME =================
              TextField(
                onChanged: controller.updateUsername,
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
              ),

              const SizedBox(height: 16),

              // ================= EMAIL =================
              TextField(
                onChanged: controller.updateEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),

              const SizedBox(height: 16),

              // ================= PASSWORD =================
              TextField(
                onChanged: controller.updatePassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
              ),

              const SizedBox(height: 16),

              // ================= CONFIRM =================
              TextField(
                onChanged: controller.updateConfirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
              ),

              const SizedBox(height: 24),

              // ================= ERROR =================
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ================= BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.canSubmit
                      ? controller.register
                      : null,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Register'),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Log in'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
