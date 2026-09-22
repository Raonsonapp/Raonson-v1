import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';

// Тасдиқи почта — қадами якум: почтаро менависед, рамз меояд.
//
// ⚠️ Ин экран пештар се камбудӣ дошт:
//
//  1. Ба `/auth/verify-email` муроҷиат мекард — чунин роҳ дар сервер
//     ВУҶУД НАДОШТ. Ҳоло ҳаст.
//  2. Ба `'/auth/otp'` мерафт — чунин роҳ дар барнома нест. Корбар
//     ба ҷои рамз экрани ВУРУДро мегирифт.
//  3. `ApiClient.post` ҳангоми 4xx хато НАМЕПАРТОЯД. Пас `try/catch`
//     ҳеҷ гоҳ кор намекард ва ҳар ҷавоб — ҳатто хато — «муваффақ»
//     ҳисоб мешуд.

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance
          .post('/auth/verify-email', body: {'email': email});

      // Маҳз ин санҷиш нарасида буд.
      if (res.statusCode >= 400) {
        if (mounted) {
          setState(() => _error = _messageOf(res.body) ?? tr('verify.failed'));
        }
        return;
      }

      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.otpVerify, arguments: email);
    } catch (_) {
      if (mounted) setState(() => _error = tr('verify.failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Матни сервер — то корбар сабаби аслиро бинад, на «хато шуд».
  String? _messageOf(String body) {
    try {
      final m = jsonDecode(body);
      final s = (m is Map ? m['message'] : null)?.toString();
      return (s == null || s.isEmpty) ? null : s;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(tr('verify.emailTitle'),
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tr('verify.emailTitle'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              tr('verify.emailSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: tr('verify.emailHint'),
                labelStyle: TextStyle(color: AppColors.textFaint),
              ),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendVerification,
                child: _isLoading
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      )
                    : Text(tr('verify.send')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
