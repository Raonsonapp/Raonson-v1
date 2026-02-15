import 'package:flutter/material.dart';
import '../auth/auth_api.dart';
import '../auth/login_screen.dart';
import '../app.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  Future<void> checkAuth() async {
    final token = await AuthApi.getToken();

    setState(() {
      loggedIn = token != null;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 🔐 Агар token ҳаст → app
    if (loggedIn) {
      return const MainNavigation();
    }

    // 🚪 Агар token нест → login
    return const LoginScreen();
  }
}
