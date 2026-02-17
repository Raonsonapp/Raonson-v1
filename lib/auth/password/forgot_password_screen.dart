import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _sendResetCode() async {
    if (_emailController.text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await ApiClient.instance.post(
        '/auth/forgot-password',
        body: {
          'email': _emailController.text.trim(),
        },
      );

      setState(() {
        _success = 'Reset code sent to email';
      });

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/auth/reset-password',
          arguments: _emailController.text.trim(),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to send reset code';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Reset your password',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your email to receive a reset code',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_success != null)
              Text(_success!, style: const TextStyle(color: Colors.green)),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendResetCode,
                child: _loading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                    : const Text('Send Reset Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
