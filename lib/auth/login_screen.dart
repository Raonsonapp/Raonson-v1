import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'verify_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController controller = TextEditingController();

  bool loading = false;
  String? error;

  bool get isEmail => controller.text.contains('@');

  Future<void> sendOtp() async {
    final value = controller.text.trim();

    if (value.isEmpty) {
      setState(() => error = 'Enter phone or email');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await AuthApi.sendOtp(value);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(value: value),
        ),
      );
    } catch (e) {
      setState(() => error = 'Failed to send code');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // LOGO / TITLE
              const Text(
                'Raonson',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),
              const Text(
                'Sign in with phone or email',
                style: TextStyle(color: Colors.white54),
              ),

              const SizedBox(height: 40),

              // INPUT
              TextField(
                controller: controller,
                keyboardType:
                    isEmail ? TextInputType.emailAddress : TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Phone number or email',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  prefixIcon: Icon(
                    isEmail ? Icons.email_outlined : Icons.phone_outlined,
                    color: Colors.white54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 30),

              // SEND OTP BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Send code',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const Spacer(),

              // FOOTER
              const Center(
                child: Text(
                  'By continuing you agree to our Terms',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
