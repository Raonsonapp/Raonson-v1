import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../auth_repository.dart';
import 'reset_password_screen.dart';
import '../../core/ui/app_icons.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _idCtrl = TextEditingController();
  final _repo = AuthRepository();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _idCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) { setState(() => _error = 'Почтаи электрониро ворид кунед'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final otp = await _repo.forgotPassword(id, channel: 'email');
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(identifier: id, prefillOtp: otp),
      ));
    } catch (_) {
      setState(() => _error = 'Хато ҳангоми фиристодан');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        title: const Text('Кӯмак барои воридшавӣ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textFaint, width: 2),
              ),
              child: Icon(AppIcons.lock_outline_rounded,
                  color: AppColors.textPrimary, size: 42),
            ),
          ),
          const SizedBox(height: 24),
          Text('Паролатонро фаромӯш кардед?',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Почтаи электронии худро ворид кунед ва мо барои '
            'барқарорсозии парол рамзи 6-рақама мефиристем.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _idCtrl,
            style: TextStyle(color: AppColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('Почтаи электронӣ'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.neonBlue.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loading ? null : _send,
              child: _loading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                  : const Text('Фиристодани рамз',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
