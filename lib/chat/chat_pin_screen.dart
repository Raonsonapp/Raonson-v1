// lib/chat/chat_pin_screen.dart
// Танзими PIN-и чат (Pro) ва варақаи кушодани чат.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/services/chat_lock_service.dart';

// ── Танзими PIN (аз Settings) ──────────────────────────────────────
class ChatPinScreen extends StatefulWidget {
  const ChatPinScreen({super.key});
  @override
  State<ChatPinScreen> createState() => _ChatPinScreenState();
}

class _ChatPinScreenState extends State<ChatPinScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _err;

  @override
  void dispose() { _pin.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _save() async {
    final p = _pin.text.trim();
    if (p.length < 4) { setState(() => _err = 'PIN ҳадди аққал 4 рақам'); return; }
    if (p != _confirm.text.trim()) {
      setState(() => _err = 'PIN-ҳо мувофиқат намекунанд'); return;
    }
    await ChatLockService.instance.setPin(p);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN-и чат гузошта шуд ✓'), backgroundColor: Colors.green));
    }
  }

  Future<void> _remove() async {
    await ChatLockService.instance.setPin(null);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN тоза шуд')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = ChatLockService.instance.hasPin;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('PIN-и чат',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(AppIcons.lock_outline_rounded, color: AppColors.neonBlue),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'Чатҳои шумо бо PIN муҳофизат мешаванд. Ҳар бор кушодан '
                'PIN лозим мешавад.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12.5))),
          ]),
          const SizedBox(height: 16),
          _pinField(_pin, 'PIN (4–6 рақам)'),
          const SizedBox(height: 12),
          _pinField(_confirm, 'Такрори PIN'),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue,
                padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: _save,
            child: const Text('Сабт', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
          )),
          if (has) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: TextButton(
              onPressed: _remove,
              child: const Text('Тоза кардани PIN',
                  style: TextStyle(color: Colors.redAccent)),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _pinField(TextEditingController c, String hint) => TextField(
    controller: c, keyboardType: TextInputType.number, obscureText: true,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: TextStyle(color: AppColors.textPrimary, fontSize: 20,
        letterSpacing: 8),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: AppColors.textFaint,
          fontSize: 14, letterSpacing: 0),
      counterText: '',
      filled: true, fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
    ),
  );
}

// ── Варақаи кушодани чат (дар chat list) ───────────────────────────
class ChatLockGate extends StatefulWidget {
  const ChatLockGate({super.key});
  @override
  State<ChatLockGate> createState() => _ChatLockGateState();
}

class _ChatLockGateState extends State<ChatLockGate> {
  final _pin = TextEditingController();
  String? _err;

  @override
  void dispose() { _pin.dispose(); super.dispose(); }

  void _try() {
    if (ChatLockService.instance.tryUnlock(_pin.text.trim())) {
      _err = null;
    } else {
      setState(() => _err = 'PIN нодуруст');
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.lock_outline_rounded,
              color: AppColors.neonBlue, size: 56),
          const SizedBox(height: 16),
          Text('Чатҳо қулф шудаанд',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('PIN-ро ворид кунед',
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          const SizedBox(height: 20),
          TextField(
            controller: _pin, keyboardType: TextInputType.number,
            obscureText: true, autofocus: true, maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            // Худкор танҳо вақте месанҷад, ки дарозӣ ба PIN-и захирашуда
            // баробар шавад — вагарна PIN-и 5-6 рақама ҳеҷ гоҳ кушода намешуд.
            onChanged: (v) {
              if (v.length == ChatLockService.instance.pinLength) _try();
            },
            onSubmitted: (_) => _try(),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24,
                letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ]),
      )),
    );
  }
}
