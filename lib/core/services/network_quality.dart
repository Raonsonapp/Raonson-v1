// lib/core/services/network_quality.dart
// Сифати видеоро вобаста ба интернет интихоб мекунад (адаптивӣ):
//   Wi-Fi / тез  → videoUrl (баланд, то 1080p)
//   Mobile / суст → videoUrlLow (~480p) — то дар H+/3G/4G шах нашавад.
//
// Илова бар навъи пайваст, акнун суръати ВОҚЕӢ чен карда мешавад: прокси-и
// видео (ниг. reels/playback/video_cache_proxy.dart) ҳар интиқоли калонро
// ба [reportTransfer] медиҳад. Wi-Fi-и суст ҳам «суст» аст ва 4G-и тез —
// «тез»; танҳо аз рӯи навъ доварӣ кардан дар Тоҷикистон хато мебарорад.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../reels/playback/playback_policy.dart';

class NetworkQuality {
  NetworkQuality._();

  static bool _fast = true; // default — баланд
  static NetKind _kind = NetKind.other;
  static final Connectivity _conn = Connectivity();
  static final BandwidthEstimator _bw = BandwidthEstimator();

  /// Ҳар тағйири навъ ё суръат (Data Saver, нақшаи пешбор онро гӯш мекунанд).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<void> init() async {
    try {
      _apply(await _conn.checkConnectivity());
      _conn.onConnectivityChanged.listen(_apply);
    } catch (_) {}
  }

  static void _apply(List<ConnectivityResult> r) {
    _fast = r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
    final kind = r.contains(ConnectivityResult.wifi) ||
            r.contains(ConnectivityResult.ethernet)
        ? NetKind.wifi
        : r.contains(ConnectivityResult.mobile)
            ? NetKind.cellular
            : (r.isEmpty || r.every((e) => e == ConnectivityResult.none))
                ? NetKind.none
                : NetKind.other;
    if (kind != _kind) {
      _kind = kind;
      // Шабакаи нав — суръати кӯҳна дигар дуруст нест.
      _bw.reset();
      changes.value++;
    }
  }

  static bool get isFast => _fast;
  static NetKind get kind => _kind;

  /// Суръати ченшуда (kbit/s) ё null.
  static double? get kbps => _bw.kbps;

  /// Суст: пайваст нест ё суръати ченшуда < 1.2 Mbps.
  static bool get isSlow => PlaybackPolicy.isSlow(_kind, _bw.kbps);

  /// Интиқоли воқеӣ (байт ва вақт) — аз прокси-и видео.
  static void reportTransfer(int bytes, Duration elapsed) {
    final wasSlow = isSlow;
    _bw.add(bytes, elapsed);
    if (wasSlow != isSlow) changes.value++;
  }

  @visibleForTesting
  static void debugSet({NetKind? kind, double? kbps}) {
    if (kind != null) _kind = kind;
    _bw.reset();
    if (kbps != null) _bw.add(1 << 20, Duration(microseconds: (8 * (1 << 20) * 1000 / kbps).round()));
    changes.value++;
  }

  /// Дар интернети суст (mobile) сифати паст, дар Wi-Fi/тез сифати баланд.
  static String pick(String high, String low) =>
      (!_fast && low.isNotEmpty) ? low : high;
}
