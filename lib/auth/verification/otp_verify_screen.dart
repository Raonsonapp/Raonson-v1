import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';

// Тасдиқи почта — қадами дуюм: рамзи аз почта омада.
//
// ⚠️ Ду камбудии ҷиддии пештара:
//
//  1. `ApiClient.post` ҳангоми 4xx хато намепартояд. Пас рамзи
//     НОДУРУСТ ҳам «тасдиқ» мешуд — экран мегузашт, гӯё ҳама чиз
//     дуруст бошад.
//  2. Баъди муваффақият ба `/login` мегузашт. Ин экран аз
//     «Танзимот → Амният» кушода мешавад, яъне корбар аллакай
//     дохил шудааст — ӯро ба вуруд бурдан хато буд.

class OtpVerifyScreen extends StatefulWidget {
  final String email;

  const OtpVerifyScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.post(
        '/auth/verify-otp',
        body: {'email': widget.email, 'otp': otp},
      );

      if (res.statusCode >= 400) {
        if (mounted) {
          setState(() => _error = _messageOf(res.body) ?? tr('verify.badCode'));
        }
        return;
      }

      if (!mounted) return;
      // Ба экрани пештара бармегардем (Танзимот → Амният), на ба вуруд.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('verify.done'))),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = tr('verify.failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        title: Text(tr('verify.codeTitle'),
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tr('verify.codeTitle'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              tr('verify.codeSentTo', {'email': widget.email}),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22),
              decoration: InputDecoration(
                labelText: tr('verify.codeHint'),
                labelStyle: TextStyle(color: AppColors.textFaint),
                counterText: '',
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
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      )
                    : Text(tr('verify.confirm')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
