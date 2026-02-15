import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  String dialCode = '+992';
  final phoneCtrl = TextEditingController();

  Future<void> sendOtp() async {
    final phone = dialCode + phoneCtrl.text.trim();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Error')),
        );
      },
      codeSent: (id, _) async {
        final code = await _enterOtp();
        if (code == null) return;

        final cred = PhoneAuthProvider.credential(
          verificationId: id,
          smsCode: code,
        );
        await FirebaseAuth.instance.signInWithCredential(cred);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<String?> _enterOtp() async {
    String code = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (v) => code = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, code),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CountryCodePicker(
                  initialSelection: 'TJ',
                  onChanged: (c) => dialCode = c.dialCode ?? '+992',
                ),
                Expanded(
                  child: TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Phone number',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendOtp,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
