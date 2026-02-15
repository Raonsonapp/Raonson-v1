import 'package:flutter/material.dart';
import 'auth_api.dart';
import '../app.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String value; // phone OR email
  const VerifyOtpScreen({super.key, required this.value});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final TextEditingController otpController = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> verifyOtp() async {
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
      // ✅ VERIFY + SAVE TOKEN
      await AuthApi.verifyOtp(
        value: widget.value,
        otp: otp,
      );

      if (!mounted) return;

      // ✅ GO TO HOME (REELS)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } catch (e) {
      setState(() => error = 'Invalid or expired code');
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
              const SizedBox(height: 30),

              // 🔙 BACK
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),

              const SizedBox(height: 20),

              // 🧾 TITLE
              const Text(
                'Enter confirmation code',
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

              // 🔢 OTP INPUT
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 6,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // ❌ ERROR
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],

              const Spacer(),

              // ✅ VERIFY BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : verifyOtp,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
