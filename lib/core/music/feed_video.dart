import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════════
//  Видеоҳои лента — қоидаҳои умумӣ (мисли Instagram).
//
//   • Танҳо ЯК видео бозӣ мекунад — ҳамоне, ки бештар намоён аст
//     ([FeedVideoFocus]). Пеш ҳар видеое, ки сохта мешуд, якбора
//     бозӣ мекард (хомӯш, вале батарея ва интернет мехӯрд).
//   • Садо — ҳамон [FeedAudio.muted]-и умумии лента: як бор садоро
//     фаъол кардед — видеоҳои навбатӣ низ бо садо мераванд.
//   • Видеои кӯтоҳ (< 20 сония) давр мезанад; дарозтар як бор
//     бозӣ мекунад ва «Боз тамошо кардан» нишон медиҳад.
// ══════════════════════════════════════════════════════════════════

/// Видеои кӯтоҳтар аз ин давр мезанад; дарозтар — як бор.
const Duration kFeedLoopMax = Duration(seconds: 20);

/// Ҳадди ақали намоёнӣ, то видео «ҷорӣ» ҳисоб шавад.
const double kFeedVideoMinVisible = 0.5;

/// Видео давр занад (true) ё як бор бозӣ кунад (false).
///
/// Давомнокии номаълум (0) — давр мезанад: беҳтар аз он ки видео
/// фавран «тамом» шавад.
bool feedVideoShouldLoop(Duration duration) =>
    duration <= Duration.zero || duration < kFeedLoopMax;

/// Видеои якбора ба охир расид — вақти «Боз тамошо кардан».
bool feedVideoFinished({
  required Duration position,
  required Duration duration,
  required bool isPlaying,
  required bool looping,
}) {
  if (looping || duration <= Duration.zero) return false;
  // Плеер баъзан чанд мс пеш аз охир меистад.
  return !isPlaying &&
      position >= duration - const Duration(milliseconds: 300);
}

/// Баландии садои видео: танҳо агар садо фаъол, пост суруд надорад
/// (суруди пост худаш мехонад — ду садо якбора намешавад) ва ҳамин
/// видео «соҳиби садо» бошад.
double feedVideoVolume({
  required bool muted,
  required bool soundless,
  required bool isOwner,
}) =>
    (!muted && !soundless && isOwner) ? 1.0 : 0.0;

/// Кадом видео ҳозир бештар намоён аст.
///
/// Ҳар видео қисми намоёни худро хабар медиҳад; [current] — калиди
/// видеое, ки бештар аз ҳама намоён аст (на камтар аз
/// [kFeedVideoMinVisible]). Баробар бошад — ҷорӣ иваз намешавад, то
/// ҳангоми ғелонидан видео «напарад».
class FeedVideoFocus {
  FeedVideoFocus();
  static final FeedVideoFocus instance = FeedVideoFocus();

  final Map<String, double> _fractions = {};
  final ValueNotifier<String?> current = ValueNotifier<String?>(null);

  void report(String key, double fraction) {
    if (fraction <= 0) {
      _fractions.remove(key);
    } else {
      _fractions[key] = fraction;
    }
    _recompute();
  }

  void remove(String key) {
    if (_fractions.remove(key) != null || current.value == key) _recompute();
  }

  bool isCurrent(String key) => current.value == key;

  void _recompute() {
    String? best;
    var bestF = kFeedVideoMinVisible - 1e-9;
    final cur = current.value;
    final curF = cur == null ? null : _fractions[cur];
    if (cur != null && curF != null && curF >= kFeedVideoMinVisible) {
      best = cur;
      bestF = curF;
    }
    _fractions.forEach((k, f) {
      if (f > bestF + 1e-6) {
        best = k;
        bestF = f;
      }
    });
    if (current.value != best) current.value = best;
  }
}
