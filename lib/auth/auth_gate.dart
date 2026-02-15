import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app.dart';
import 'send_otp_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // logged in
        if (snapshot.hasData) {
          return const RaonsonApp();
        }

        // not logged in
        return const SendOtpScreen();
      },
    );
  }
}
