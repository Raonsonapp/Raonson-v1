import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'gmail_screen.dart';

class OtpScreen extends StatelessWidget {
  final String phone;
  final controller = TextEditingController();

  OtpScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OTP")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(hintText: "6 digit code"),
            ),
            ElevatedButton(
              onPressed: () async {
                final tempToken = await AuthApi.verifyOtp(
                  phone,
                  controller.text,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GmailScreen(tempToken: tempToken),
                  ),
                );
              },
              child: const Text("Verify OTP"),
            )
          ],
        ),
      ),
    );
  }
}
