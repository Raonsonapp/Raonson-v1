// lib/core/translate/translate_service.dart
//
// «Тарҷума» — ягона роҳ барои тавсиф, шарҳ, паём ва bio.
//
// Пеш се ҷои барнома ҳар кадом /ai/translate-ро худаш мезад, бо забони
// гуногун (баъзан ҳамеша 'en') ва бе кэш. Акнун:
//   • сервер: POST /translate (кэш аз рӯи матн ва забон, ҳадди корбар);
//   • забони мақсад — забони барнома;
//   • кэши хотира: ҳамон матн дар ҳамон ҷаласа дубора фиристода намешавад.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../app/app_settings.dart';
import '../api/api_client.dart';

/// Натиҷаи тарҷума.
class TranslateResult {
  final String text;
  /// Код барои хато: 'disabled' | 'limited' | 'tooLong' | 'failed'.
  final String? error;
  const TranslateResult.ok(this.text) : error = null;
  const TranslateResult.fail(this.error) : text = '';
  bool get isOk => error == null;
}

/// Манбаи тарҷума (дар тест иваз мешавад).
typedef TranslateBackend = Future<TranslateResult> Function(
    String text, String target);

class TranslateService {
  TranslateService._();
  static final TranslateService instance = TranslateService._();

  final Map<String, String> _memo = {};

  @visibleForTesting
  TranslateBackend? debugBackend;

  /// Забони мақсад: забони барнома.
  static String get targetLang => AppSettingsState.instance.lang;

  Future<TranslateResult> translate(String text, {String? target}) async {
    final t = text.trim();
    if (t.isEmpty) return const TranslateResult.fail('failed');
    final lang = target ?? targetLang;
    final key = '$lang\u0000$t';
    final hit = _memo[key];
    if (hit != null) return TranslateResult.ok(hit);
    final res = await (debugBackend ?? _server)(t, lang);
    if (res.isOk) {
      if (_memo.length > 300) _memo.clear();
      _memo[key] = res.text;
    }
    return res;
  }

  static Future<TranslateResult> _server(String text, String target) async {
    try {
      final r = await ApiClient.instance
          .post('/translate', body: {'text': text, 'target': target});
      Map<String, dynamic> b = const {};
      try {
        b = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
      if (r.statusCode < 400) {
        final out = (b['translated'] ?? '').toString();
        return out.isEmpty
            ? const TranslateResult.fail('failed')
            : TranslateResult.ok(out);
      }
      switch (r.statusCode) {
        case 503:
          return const TranslateResult.fail('disabled');
        case 429:
          return const TranslateResult.fail('limited');
        case 413:
          return const TranslateResult.fail('tooLong');
      }
    } catch (_) {}
    return const TranslateResult.fail('failed');
  }

  @visibleForTesting
  void debugClear() => _memo.clear();
}
