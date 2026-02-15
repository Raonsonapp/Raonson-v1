import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();

  Future<void> register() async {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.text.trim(),
      password: pass.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: email, decoration: const InputDecoration(hintText: 'Email')),
            TextField(controller: pass, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: register, child: const Text('Create account')),
          ],
        ),
      ),
    );
  }
}
