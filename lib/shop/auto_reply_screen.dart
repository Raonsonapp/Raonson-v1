// lib/shop/auto_reply_screen.dart
// Ҷавоби худкор — вақте муштарӣ бори аввал нома нависад, худкор ҷавоб меравад.
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';

class AutoReplyScreen extends StatefulWidget {
  const AutoReplyScreen({super.key});
  @override
  State<AutoReplyScreen> createState() => _AutoReplyState();
}

class _AutoReplyState extends State<AutoReplyScreen> {
  final _ctrl = TextEditingController();
  bool _loading = true, _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await ApiClient.instance.get('/profile/auto-reply');
      if (r.statusCode < 400) {
        _ctrl.text = (jsonDecode(r.body)['autoReply'] ?? '').toString();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final okRes = await ApiClient.instance.put('/profile/auto-reply',
          body: {'text': _ctrl.text.trim()});
      if (okRes.statusCode >= 400) throw Exception();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('ui.3358400c00')),
            backgroundColor: Colors.green));
      }
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ui.5fae95bc45'),
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            Padding(padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(onPressed: _save,
                child: Text(tr('ui.cb206b6c88'), style: TextStyle(color: AppColors.neonBlue,
                    fontWeight: FontWeight.bold, fontSize: 15))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(AppIcons.chat_bubble_rounded,
                        color: AppColors.neonBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'Вақте муштарӣ бори аввал ба шумо нома менависад, '
                        'ин паём худкор фиристода мешавад.',
                        style: TextStyle(color: AppColors.textFaint,
                            fontSize: 12.5))),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ctrl,
                    maxLines: 5, maxLength: 500,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: tr('ui.f4ef65a377'),
                      hintStyle: TextStyle(color: AppColors.textFaint),
                      filled: true, fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('ui.6721b21fc6'),
                      style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ]),
            ),
    );
  }
}
