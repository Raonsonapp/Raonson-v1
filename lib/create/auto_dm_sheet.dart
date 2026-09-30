import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

/// Паёми худкор ба Direct аз рӯи калимаи шарҳ — мисли ManyChat.
///
/// Муаллиф калимаҳо («1», «салом», «нарх») ва паём/пайвандро мегузорад.
/// Касе, ки шарҳ бо яке аз ин калимаҳо нависад, фавран ба Direct паём
/// мегирад (ҳар кас танҳо як бор). Сервер ҳамаро месанҷад.
class AutoDmDraft {
  final List<String> keywords;
  final bool anyWord;
  final String message;
  final String link;
  final bool enabled;

  const AutoDmDraft({
    this.keywords = const [],
    this.anyWord = false,
    this.message = '',
    this.link = '',
    this.enabled = true,
  });

  factory AutoDmDraft.fromJson(Map<String, dynamic> j) => AutoDmDraft(
        keywords: (j['keywords'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        anyWord: j['anyWord'] == true,
        message: (j['message'] ?? '').toString(),
        link: (j['link'] ?? '').toString(),
        enabled: j['enabled'] != false,
      );

  Map<String, dynamic> toJson() => {
        'keywords': keywords,
        'anyWord': anyWord,
        'message': message,
        'link': link,
        'enabled': enabled,
      };

  /// Калимаҳо аз сатри «1, салом, нарх».
  static List<String> parseKeywords(String raw) => raw
      .split(RegExp(r'[,،;\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .take(10)
      .toList();

  /// Хатои санҷиш ё null. Ҳамон қоидаҳое, ки сервер дорад.
  String? validate() {
    final l = link.trim();
    if (l.isNotEmpty) {
      final u = Uri.tryParse(l);
      if (u == null || u.scheme != 'https' || u.host.isEmpty || l.contains(' ')) {
        return 'Пайванд бояд бо https:// оғоз шавад';
      }
    }
    if (message.trim().isEmpty && l.isEmpty) return 'Паём ё пайванд нависед';
    if (!anyWord && keywords.isEmpty) {
      return 'Калима нависед ё «Ба ҳар шарҳ»-ро фаъол кунед';
    }
    return null;
  }
}

/// Муҳаррир. Бармегардонад: қоидаи нав, `AutoDmResult.removed`, ё null (бекор).
Future<Object?> showAutoDmEditor(BuildContext context,
    {AutoDmDraft? initial, bool canRemove = false}) {
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151515),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AutoDmEditor(initial: initial, canRemove: canRemove),
  );
}

class AutoDmResult {
  static const removed = AutoDmResult._();
  const AutoDmResult._();
}

/// Барои пост/рилси аллакай нашршуда: аз сервер мехонад ва сабт мекунад.
Future<void> openAutoDmSettings(
    BuildContext context, String kind, String id) async {
  final messenger = ScaffoldMessenger.of(context);
  AutoDmDraft? current;
  int sent = 0;
  try {
    final res = await ApiClient.instance.getOk('/auto-dm/$kind/$id');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['exists'] == true) current = AutoDmDraft.fromJson(j);
    sent = (j['sentCount'] as num?)?.toInt() ?? 0;
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Танзимот бор нашуд. Интернетро санҷед')));
    return;
  }
  if (!context.mounted) return;
  final r = await showAutoDmEditor(context,
      initial: current, canRemove: current != null);
  try {
    if (r == AutoDmResult.removed) {
      await ApiClient.instance.deleteOk('/auto-dm/$kind/$id');
      messenger.showSnackBar(
          const SnackBar(content: Text('Паёми худкор хомӯш шуд')));
    } else if (r is AutoDmDraft) {
      await ApiClient.instance.putOk('/auto-dm/$kind/$id', body: r.toJson());
      messenger.showSnackBar(SnackBar(
          content: Text(r.enabled
              ? 'Паёми худкор фаъол шуд${sent > 0 ? ' · то ҳол $sent нафар гирифтанд' : ''}'
              : 'Паёми худкор таваққуф шуд')));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text((e is ApiException ? e.message : null) ?? 'Сабт нашуд')));
  }
}

class _AutoDmEditor extends StatefulWidget {
  final AutoDmDraft? initial;
  final bool canRemove;
  const _AutoDmEditor({this.initial, this.canRemove = false});
  @override
  State<_AutoDmEditor> createState() => _AutoDmEditorState();
}

class _AutoDmEditorState extends State<_AutoDmEditor> {
  late final TextEditingController _kw;
  late final TextEditingController _msg;
  late final TextEditingController _link;
  late bool _anyWord;
  late bool _enabled;
  String? _error;

  static const _accent = Color(0xFF00C6FF);

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const AutoDmDraft();
    _kw = TextEditingController(text: i.keywords.join(', '));
    _msg = TextEditingController(text: i.message);
    _link = TextEditingController(text: i.link);
    _anyWord = i.anyWord;
    _enabled = i.enabled;
  }

  @override
  void dispose() {
    _kw.dispose();
    _msg.dispose();
    _link.dispose();
    super.dispose();
  }

  void _save() {
    final d = AutoDmDraft(
      keywords: AutoDmDraft.parseKeywords(_kw.text),
      anyWord: _anyWord,
      message: _msg.text.trim(),
      link: _link.text.trim(),
      enabled: _enabled,
    );
    final err = d.validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, d);
  }

  InputDecoration _dec(String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: icon == null ? null : Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: const Color(0xFF222222),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final keywords = AutoDmDraft.parseKeywords(_kw.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              const Row(children: [
                Icon(AppIcons.chat_bubble_outline, color: _accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Паёми худкор ба Direct',
                      style: TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Касе шарҳ бо калимаи шумо нависад — фавран ба Direct-аш паём ва '
                'пайванд меравад. Ҳар кас танҳо як бор мегирад.',
                style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.35),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _accent,
                value: _anyWord,
                onChanged: (v) => setState(() { _anyWord = v; _error = null; }),
                title: const Text('Ба ҳар шарҳ',
                    style: TextStyle(color: Colors.white, fontSize: 14.5)),
                subtitle: const Text('Калимаи мушаххас лозим нест',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              if (!_anyWord) ...[
                _label('Калимаҳои калидӣ (бо вергул)'),
                TextField(
                  controller: _kw,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('масалан: 1, салом, нарх'),
                  onChanged: (_) => setState(() => _error = null),
                ),
                if (keywords.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final k in keywords)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: _accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(k,
                              style: const TextStyle(color: _accent, fontSize: 12.5)),
                        ),
                    ]),
                  ),
              ],
              _label('Паём'),
              TextField(
                controller: _msg,
                maxLines: 4,
                minLines: 2,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Ташаккур барои шарҳ! Инак маълумоти пурра:'),
                onChanged: (_) => setState(() => _error = null),
              ),
              _label('Пайванд (ихтиёрӣ)'),
              TextField(
                controller: _link,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('https://...', icon: AppIcons.link),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (widget.initial != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _accent,
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Фаъол',
                      style: TextStyle(color: Colors.white, fontSize: 14.5)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _save,
                  child: const Text('Сабт',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              if (widget.canRemove)
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context, AutoDmResult.removed),
                    icon: const Icon(AppIcons.delete_outline, color: Colors.redAccent, size: 18),
                    label: const Text('Нест кардан',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
