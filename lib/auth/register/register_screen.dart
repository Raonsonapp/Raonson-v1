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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ✅ LOGO
              Image.asset(
                'assets/icon/logo.png',
                height: 120,
              ),

              const SizedBox(height: 24),

              const Text(
                'Create Raonson Account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 32),

              TextField(
                onChanged: controller.updateUsername,
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                onChanged: controller.updateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                onChanged: controller.updatePassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                onChanged: controller.updateConfirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
              ),

              const SizedBox(height: 24),

              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.canSubmit
                      ? () => controller.register(context)
                      : null,
                  child: state.isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text('Register'),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Log in'),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
