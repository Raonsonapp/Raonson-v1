import 'package:flutter/material.dart';
import '../app_routes.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.app);
          },
          child: const Text('Finish Registration'),
        ),
      ),
    );
  }
}
