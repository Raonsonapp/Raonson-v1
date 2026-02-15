import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verify_otp_screen.dart';

class SendOtpScreen extends StatefulWidget {
  const SendOtpScreen({super.key});

  @override
  State<SendOtpScreen> createState() => _SendOtpScreenState();
}

class _SendOtpScreenState extends State<SendOtpScreen> {
  final controller = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> sendCode() async {
    final value = controller.text.trim();
    if (value.isEmpty) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (value.contains('@')) {
        // EMAIL
        await FirebaseAuth.instance.sendSignInLinkToEmail(
          email: value,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://raonson.firebaseapp.com',
            handleCodeInApp: true,
            androidPackageName: 'com.example.raonson',
            androidInstallApp: true,
            androidMinimumVersion: '1',
          ),
        );
      } else {
        // PHONE
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: value,
          verificationCompleted: (_) {},
          verificationFailed: (e) {
            throw e;
          },
          codeSent: (id, _) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerifyOtpScreen(
                  verificationId: id,
                ),
              ),
            );
          },
          codeAutoRetrievalTimeout: (_) {},
        );
      }
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Login or Register',
              style: TextStyle(color: Colors.white, fontSize: 26),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email or phone (+992...)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1C1C1C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : sendCode,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
