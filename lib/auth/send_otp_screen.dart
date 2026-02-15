import 'package:flutter/material.dart';
import 'verify_otp_screen.dart';
import 'auth_api.dart';

class SendOtpScreen extends StatefulWidget {
  const SendOtpScreen({super.key});

  @override
  State<SendOtpScreen> createState() => _SendOtpScreenState();
}

class _SendOtpScreenState extends State<SendOtpScreen> {
  final TextEditingController controller = TextEditingController();
  bool loading = false;
  String? error;

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
    } catch (_) {
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
            children: [
              const SizedBox(height: 60),
              const Text(
                'Login or Register',
                style: TextStyle(color: Colors.white, fontSize: 26),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: controller,
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
                  onPressed: loading ? null : sendOtp,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
