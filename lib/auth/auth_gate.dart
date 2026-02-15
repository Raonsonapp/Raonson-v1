import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app.dart';
import 'auth_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) return const MainNavigation();
        return const AuthHomeScreen();
      },
    );
  }
}
