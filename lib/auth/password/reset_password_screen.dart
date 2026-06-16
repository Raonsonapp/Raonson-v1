import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;
  final String? prefillOtp;
  const ResetPasswordScreen({super.key, required this.identifier, this.prefillOtp});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _repo = AuthRepository();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefillOtp != null && widget.prefillOtp!.isNotEmpty) {
      _otpCtrl.text = widget.prefillOtp!;
    }
  }

  @override
  void dispose() { _otpCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _reset() async {
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    if (otp.length < 4) { setState(() => _error = 'Рамзи 6-рақамаро ворид кунед'); return; }
    if (pass.length < 6) { setState(() => _error = 'Парол ҳадди ақал 6 аломат'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await _repo.resetPassword(
          identifier: widget.identifier, otp: otp, newPassword: pass);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Парол иваз шуд ✓'),
          backgroundColor: Colors.green));
        Navigator.popUntil(context, (r) => r.isFirst);
      } else {
        setState(() => _error = 'Рамз нодуруст ё кӯҳна');
      }
    } catch (_) {
      setState(() => _error = 'Хато ҳангоми барқарорсозӣ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        title: const Text('Рамзро ворид кунед',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Text('Рамзи 6-рақамаро, ки ба ${widget.identifier} '
              'фиристодем, ворид кунед ва пароли нав созед.',
              style: const TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 22),
          TextField(
            controller: _otpCtrl,
            style: const TextStyle(color: Colors.white,
                fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec('• • • • • •').copyWith(counterText: ''),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Пароли нав').copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined, color: Colors.white38, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
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
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.neonBlue.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _loading ? null : _reset,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Иваз кардани парол',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}
