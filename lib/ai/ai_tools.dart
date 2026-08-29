// lib/ai/ai_tools.dart
// AI-абзорҳо (Pro): Caption, Hashtag, Беҳтар кардан, Тарҷума.
// Ба TextEditingController-и додашуда натиҷаро мегузорад.
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../core/services/subscription_service.dart';
import '../subscription/subscription_screen.dart';
import '../core/i18n/strings.dart';

class AiService {
  static Future<String> text(String task, String input, {String lang = ''}) async {
    try {
      final r = await ApiClient.instance.post('/ai/text',
          body: {'task': task, 'text': input, 'lang': lang})
        .timeout(const Duration(seconds: 45));
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        if (b['configured'] == false) return '__NOT_CONFIGURED__';
        return (b['result'] ?? '').toString();
      }
    } catch (_) {}
    return '';
  }
}

/// Тугмаи ✨ AI, ки менюи абзорҳоро мекушояд ва натиҷаро ба [controller] мегузорад.
class AiToolsButton extends StatefulWidget {
  final TextEditingController controller;
  final bool appendHashtags; // барои хэштег: илова кун, на иваз
  const AiToolsButton({super.key, required this.controller,
      this.appendHashtags = true});
  @override
  State<AiToolsButton> createState() => _AiToolsButtonState();
}

class _AiToolsButtonState extends State<AiToolsButton> {
  bool _busy = false;

  void _openMenu() {
    // AI — хусусияти Pro.
    if (!SubscriptionService.instance.isPro) {
      _proGate();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(AppIcons.bolt_rounded, color: const Color(0xFFE100FF), size: 18),
            const SizedBox(width: 6),
            Text(tr('ui.d379837116'),
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 6),
          _item('caption', AppIcons.edit_outlined, 'Навиштани Caption',
              'AI барои шумо матн менависад'),
          _item('hashtags', AppIcons.tag_rounded, 'Пешниҳоди Hashtag',
              'Хэштегҳои мувофиқ'),
          _item('improve', AppIcons.auto_awesome_rounded, 'Беҳтар кардани матн',
              'Ислоҳи имло ва услуб'),
          _item('translate', AppIcons.language_rounded, 'Тарҷума ба English',
              'Матнро тарҷума мекунад'),
          const SizedBox(height: 12),
        ])),
    );
  }

  Widget _item(String task, IconData icon, String title, String sub) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neonBlue),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(sub,
          style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      onTap: () { Navigator.pop(context); _run(task); },
    );
  }

  Future<void> _run(String task) async {
    setState(() => _busy = true);
    final lang = task == 'translate' ? 'en' : '';
    final res = await AiService.text(task, widget.controller.text.trim(),
        lang: lang);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == '__NOT_CONFIGURED__') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('ui.6041188b9a'))));
      return;
    }
    if (res.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('ui.af517eb55b'))));
      return;
    }
    setState(() {
      if (task == 'hashtags' && widget.appendHashtags) {
        final cur = widget.controller.text.trimRight();
        widget.controller.text = cur.isEmpty ? res : '$cur\n\n$res';
      } else {
        widget.controller.text = res;
      }
      widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length));
    });
  }

  void _proGate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.bolt_rounded, color: const Color(0xFFE100FF), size: 40),
          const SizedBox(height: 12),
          Text(tr('ui.4c0742534e'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(tr('ui.a81915825e'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE100FF),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen()));
              },
              child: Text(tr('ui.a26ac78e3e'),
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _openMenu,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7F00FF), Color(0xFFE100FF)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _busy
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(AppIcons.bolt_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          const Text('AI', style: TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
