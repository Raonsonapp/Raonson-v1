import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

// ══════════════════════════════════════════════════════════════════
//  Калимаҳои пинҳон.
//
//  Шарҳе, ки ин калимаҳоро дорад, РАД НАМЕШАВАД — он пинҳон
//  мешавад. Нависанда шарҳи худро мебинад ва намедонад, ки дигарон
//  онро намебинанд.
//
//  Ин қасдан аст: агар ӯ мефаҳмид, роҳи гузаштанро меҷуст
//  («с.а.л.о.м»).
// ══════════════════════════════════════════════════════════════════

class HiddenWordsScreen extends StatefulWidget {
  const HiddenWordsScreen({super.key});

  @override
  State<HiddenWordsScreen> createState() => _HiddenWordsScreenState();
}

class _HiddenWordsScreenState extends State<HiddenWordsScreen> {
  final _ctrl = TextEditingController();
  List<String> _words = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.get('/profile/hidden-words');
      if (res.statusCode >= 400) throw Exception('${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['words'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _words = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Бор карда нашуд';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Нусхаи пеш аз тағйир — барои баргардонидан ҳангоми нокомӣ.
    final before = List<String>.from(_words);
    try {
      final res = await ApiClient.instance
          .put('/profile/hidden-words', body: {'words': _words});
      if (res.statusCode >= 400) throw Exception('${res.statusCode}');
    } catch (_) {
      if (!mounted) return;
      // Сервер қабул накард — экран набояд дурӯғ нишон диҳад.
      setState(() => _words = before);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нигоҳ дошта нашуд')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _add() {
    final w = _ctrl.text.trim().toLowerCase();
    if (w.isEmpty || _words.contains(w)) {
      _ctrl.clear();
      return;
    }
    setState(() {
      _words.add(w);
      _ctrl.clear();
    });
    _save();
  }

  void _remove(String w) {
    setState(() => _words.remove(w));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text('Калимаҳои пинҳон',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textFaint)),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.textFaint))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Шарҳе, ки ин калимаҳоро дорад, аз постҳои шумо '
                  'пинҳон мешавад.\n\n'
                  'Нависанда шарҳи худро мебинад ва намедонад, ки он '
                  'пинҳон шуд — пас роҳи гузаштанро намеҷӯяд.',
                  style: TextStyle(
                      color: AppColors.textTertiary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        hintText: 'Калима ё ибора',
                        hintStyle: TextStyle(color: AppColors.textFaint),
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Илова',
                          style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                if (_error != null)
                  _Retry(message: _error!, onRetry: _load)
                else if (_words.isEmpty)
                  _Empty()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _words
                        .map((w) => Chip(
                              backgroundColor: AppColors.card,
                              label: Text(w,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                              deleteIcon: Icon(AppIcons.close_rounded,
                                  size: 15, color: AppColors.textTertiary),
                              onDeleted: () => _remove(w),
                            ))
                        .toList(),
                  ),
              ],
            ),
    );
  }
}

/// Ҳолати холӣ бо қадами оянда — на танҳо «холӣ».
class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(AppIcons.privacy_tip_outlined,
              size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text('Ҳанӯз калимае нест',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Калимаеро илова кунед, ки дидан намехоҳед',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
        ]),
      );
}

/// Хато + такрор — ҳар дархост бояд роҳи барқароршавӣ дошта бошад.
class _Retry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Retry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(AppIcons.error_outline_rounded,
              size: 40, color: AppColors.textFaint),
          const SizedBox(height: 10),
          Text(message,
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Такрор',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
}
