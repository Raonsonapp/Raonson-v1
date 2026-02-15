import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'verify_otp_screen.dart';

class PhoneOrEmailScreen extends StatefulWidget {
  const PhoneOrEmailScreen({super.key});

  @override
  State<PhoneOrEmailScreen> createState() => _PhoneOrEmailScreenState();
}

class _PhoneOrEmailScreenState extends State<PhoneOrEmailScreen> {
  final TextEditingController controller = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> sendCode() async {
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
              const SizedBox(height: 40),

              const Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'Enter phone number or email',
                style: TextStyle(color: Colors.white54),
              ),

              const SizedBox(height: 30),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Phone or Email',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Send code',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
