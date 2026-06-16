import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../auth_repository.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _idCtrl = TextEditingController();
  final _repo = AuthRepository();
  String _channel = 'email'; // email | sms | whatsapp
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _idCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) { setState(() => _error = 'Email ё рақами телефонро ворид кунед'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final otp = await _repo.forgotPassword(id, channel: _channel);
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
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
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Colors.white, size: 42),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Паролатонро фаромӯш кардед?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white,
                  fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Email ё рақами телефони худро ворид кунед ва мо барои '
            'барқарорсозии парол рамзи 6-рақама мефиристем.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _idCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('Email ё рақами телефон'),
          ),
          const SizedBox(height: 18),
          const Text('Рамзро ба куҷо фиристем?',
              style: TextStyle(color: Colors.white70, fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _channelChip('email', Icons.email_outlined, 'Email'),
            const SizedBox(width: 8),
            _channelChip('sms', Icons.sms_outlined, 'SMS'),
            const SizedBox(width: 8),
            _channelChip('whatsapp', Icons.chat_outlined, 'WhatsApp'),
          ]),
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
              onPressed: _loading ? null : _send,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Фиристодани рамз',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelChip(String value, IconData icon, String label) {
    final sel = _channel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _channel = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.neonBlue.withOpacity(0.15) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? AppColors.neonBlue : Colors.white12,
                width: sel ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? AppColors.neonBlue : Colors.white60, size: 22),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(
                color: sel ? Colors.white : Colors.white60,
                fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
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
