import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../app.dart';
import 'auth_api.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController usernameCtrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> submit() async {
    final username = usernameCtrl.text.trim();

    if (username.length < 3) {
      setState(() => error = 'Username too short');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final token = await AuthApi.getToken();

      final res = await http.post(
        Uri.parse('${Constants.baseUrl}/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': username,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception();
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } catch (_) {
      setState(() => error = 'Registration failed');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Create username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),
              const Text(
                'This will be your public name',
                style: TextStyle(color: Colors.white54),
              ),

              const SizedBox(height: 30),
              TextField(
                controller: usernameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'username',
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
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Continue',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
