// lib/learn/tutor_chat_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

class TutorChatScreen extends StatefulWidget {
  final String track, trackName;
  const TutorChatScreen(
      {super.key, required this.track, required this.trackName});
  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  // {role: user|assistant, content}
  final List<Map<String, String>> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Худкор аз Устоз дарси якумро мепурсем.
    _send(
      'Салом Устоз! Ман мехоҳам «${widget.trackName}»-ро аз сифр ёд гирам. '
      'Аз қадами якуми хеле содда оғоз кун ва дар охир ба ман як вазифаи хурд деҳ.',
      hidden: true,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text, {bool hidden = false}) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() {
      if (!hidden) _messages.add({'role': 'user', 'content': text.trim()});
      _sending = true;
    });
    if (!hidden) _ctrl.clear();
    _scrollDown();
    // Барои дархост — таърихро мефиристем (агар hidden бошад, паёми ниҳонро ҳам).
    final history = List<Map<String, String>>.from(_messages);
    if (hidden) history.add({'role': 'user', 'content': text.trim()});
    try {
      final r = await ApiClient.instance.post('/tutor/chat', body: {
        'track': widget.track,
        'messages': history,
      }).timeout(const Duration(seconds: 50));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('ui.89cfc5d1b3'),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text(widget.trackName,
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ],
        ),
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
          Text(tr('ui.3b2e899b3f'),
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
        child: mine
            ? Text(content,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15))
            : _richReply(content),
      ),
    );
  }

  // Ҷавоби Устозро бо блокҳои код (``` ```) зебо нишон медиҳем.
  Widget _richReply(String content) {
    final parts = content.split('```');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < parts.length; i++)
          if (parts[i].trim().isNotEmpty)
            i.isOdd
                ? _codeBlock(_stripLang(parts[i]))
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(parts[i].trim(),
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 15,
                            height: 1.4)),
                  ),
      ],
    );
  }

  String _stripLang(String code) {
    final lines = code.split('\n');
    if (lines.isNotEmpty &&
        lines.first.trim().isNotEmpty &&
        !lines.first.contains(' ') &&
        lines.length > 1) {
      return lines.sublist(1).join('\n');
    }
    return code;
  }

  Widget _codeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerFaint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(code.trim(),
                style: const TextStyle(
                    color: Color(0xFF9CDCFE), fontSize: 13,
                    fontFamily: 'monospace', height: 1.45)),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code.trim()));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('ui.edfa71f0d9')),
                  duration: Duration(seconds: 1)));
            },
            child: Icon(AppIcons.copy_rounded,
                color: AppColors.textFaint, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 6, 8, 6),
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
                hintText: tr('ui.3e41b4b77d'),
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
