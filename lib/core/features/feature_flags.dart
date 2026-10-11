// lib/core/features/feature_flags.dart
//
// Парчамҳои сервер (GET /features): кадом функсия дар ҳамин сервер фаъол
// аст. Масалан, «Тарҷума» танҳо вақте нишон дода мешавад, ки провайдери
// AI танзим шудааст — вагарна тугма ҳамеша «Тарҷума нашуд» мегуфт.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class FeatureFlags {
  final bool translate;
  final int translateMax;
  final List<String> translateLangs;
  final int voiceMaxSeconds;

  const FeatureFlags({
    this.translate = false,
    this.translateMax = 2000,
    this.translateLangs = const ['tj', 'ru', 'en', 'fa', 'uz'],
    this.voiceMaxSeconds = 60,
  });

  /// То ҷавоби сервер: тарҷума пинҳон (беҳтар аз тугмаи бекор).
  static const off = FeatureFlags();

  factory FeatureFlags.fromJson(Map<String, dynamic> j) => FeatureFlags(
        translate: j['translate'] == true,
        translateMax: (j['translateMax'] as num?)?.toInt() ?? 2000,
        translateLangs: ((j['translateLangs'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        voiceMaxSeconds: (j['voiceMaxSeconds'] as num?)?.toInt() ?? 60,
      );

  /// Ҳолати ҷорӣ; виджетҳо ба он гӯш медиҳанд.
  static final ValueNotifier<FeatureFlags> current =
      ValueNotifier<FeatureFlags>(off);

  static Future<void>? _loading;

  /// Як бор дар як ҷаласа бор мекунад (такрор — ҳамон Future).
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final r = await ApiClient.instance.get('/features');
      if (r.statusCode < 400) {
        current.value = FeatureFlags.fromJson(
            jsonDecode(r.body) as Map<String, dynamic>);
        return;
      }
    } catch (_) {/* бе шабака — пинҳон мемонад */}
    // Дафъаи оянда боз кӯшиш карда шавад.
    _loading = null;
  }

  @visibleForTesting
  static void debugSet(FeatureFlags f) {
    current.value = f;
    _loading = Future.value();
  }

  @visibleForTesting
  static void debugReset() {
    current.value = off;
    _loading = null;
  }
}
