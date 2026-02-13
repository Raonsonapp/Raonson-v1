import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatelessWidget {
  final controller = TextEditingController();

  PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Phone")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: "559994751",
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await AuthApi.sendOtp(controller.text);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OtpScreen(phone: controller.text),
                  ),
                );
              },
              child: const Text("Send OTP"),
            )
          ],
        ),
      ),
    );
  }
}
