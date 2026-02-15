import 'package:flutter/material.dart';
import 'auth_api.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String value; // phone or email
  const VerifyOtpScreen({super.key, required this.value});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final TextEditingController otpController = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> verify() async {
    final otp = otpController.text.trim();
    if (otp.length < 4) {
      setState(() => error = 'Enter valid code');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final token = await AuthApi.verifyOtp(
        value: widget.value,
        otp: otp,
      );

      // 🔐 TODO (қадами баъдӣ): token-ро дар storage нигоҳ медорем
      // await SecureStorage.saveToken(token);

      if (!mounted) return;

      // 👉 redirect to main app (Reels / Home)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (_) => false,
      );
    } catch (e) {
      setState(() => error = 'Invalid code');
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
                'Enter code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'We sent a code to ${widget.value}',
                style: const TextStyle(color: Colors.white54),
              ),

              const SizedBox(height: 30),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 6,
                  fontSize: 20,
                ),
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
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
                  onPressed: loading ? null : verify,
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
                          'Verify',
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
