import 'package:flutter/material.dart';
import 'auth_api.dart';
import '../home/home_screen.dart';

class GmailScreen extends StatelessWidget {
  final String tempToken;
  final controller = TextEditingController();

  GmailScreen({super.key, required this.tempToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gmail")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration:
                  const InputDecoration(hintText: "test@gmail.com"),
            ),
            ElevatedButton(
              onPressed: () async {
                final token = await AuthApi.verifyGmail(
                  controller.text,
                  tempToken,
                );

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(token: token),
                  ),
                );
              },
              child: const Text("Finish"),
            )
          ],
        ),
      ),
    );
  }
}
