import 'package:flutter/material.dart';
import 'phone_login_screen.dart';
import 'email_login_screen.dart';

class AuthHomeScreen extends StatelessWidget {
  const AuthHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF6A00),
              Color(0xFFFF0000),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),

              Image.asset(
                'assets/logo.png',
                width: 120,
              ),

              const SizedBox(height: 40),

              const Text(
                'Login or Register',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              _btn(
                context,
                text: 'Continue with Phone',
                screen: const PhoneLoginScreen(),
              ),

              const SizedBox(height: 16),

              _btn(
                context,
                text: 'Continue with Email',
                screen: const EmailLoginScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(
    BuildContext context, {
    required String text,
    required Widget screen,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: ElevatedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
