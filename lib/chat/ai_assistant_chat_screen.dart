// lib/chat/ai_assistant_chat_screen.dart
// Ёрдамчии AI дар дохили бахши Чат — саволҳо оид ба барнома ва мӯҳтавои он.
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});
  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  // {role: user|assistant, content}
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'Салом! Ман ёрдамчии AI-и Raonson ҳастам 👋\n'
          'Дар бораи барнома (пост, Reels, story, чат ва ғайра) ё '
          'мӯҳтавои видеоҳо чизе бипурсед.',
    },
  ];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text.trim()});
      _sending = true;
    });
    _ctrl.clear();
    _scrollDown();
    final history = _messages
        .map((m) => {'role': m['role'] ?? 'user', 'content': m['content'] ?? ''})
        .toList();
    try {
      final r = await ApiClient.instance.post('/ai/assistant', body: {
        'messages': history,
      }).timeout(const Duration(seconds: 40));
      String reply = 'Узр, ҷавоб нашуд. Дубора кӯшиш кун 🙏';
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body);
        reply = (b['reply'] ?? reply).toString();
      }
      if (mounted) {
        setState(() => _messages.add({'role': 'assistant', 'content': reply}));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add({
              'role': 'assistant',
              'content': 'Пайвастшавӣ нашуд. Интернетро тафтиш кун ва дубора кӯшиш кун 🙏'
            }));
      }
    }
    if (mounted) setState(() => _sending = false);
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF00E87A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Icon(AppIcons.bolt_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(tr('ui.e2a057248b'),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _messages.length) return _typing();
              final m = _messages[i];
              return _bubble(m['role'] == 'user', m['content'] ?? '');
            },
          ),
        ),
        _inputBar(),
      ]),
    );
  }

  Widget _typing() => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(AppIcons.bolt_rounded, color: AppColors.neonBlue, size: 18),
          const SizedBox(width: 8),
          Text(tr('ui.f7a42633ff'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
        ]),
      );

  Widget _bubble(bool mine, String content) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.neonBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(content,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4)),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.dividerFaint))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: AppColors.textPrimary),
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (t) => _send(t),
              decoration: InputDecoration(
                hintText: tr('ui.787d741abc'),
                hintStyle: TextStyle(color: AppColors.textFaint),
                filled: true, fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          IconButton(
            icon: Icon(AppIcons.send_rounded, color: AppColors.neonBlue),
            onPressed: _sending ? null : () => _send(_ctrl.text),
          ),
        ]),
      ),
    );
  }
}
