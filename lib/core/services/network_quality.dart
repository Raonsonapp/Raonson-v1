// lib/core/services/network_quality.dart
// Сифати видеоро вобаста ба интернет интихоб мекунад (адаптивӣ):
//   Wi-Fi / тез  → videoUrl (баланд, то 1080p)
//   Mobile / суст → videoUrlLow (~480p) — то дар H+/3G/4G шах нашавад.
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkQuality {
  NetworkQuality._();

  static bool _fast = true; // default — баланд
  static final Connectivity _conn = Connectivity();

  static Future<void> init() async {
    try {
      _apply(await _conn.checkConnectivity());
      _conn.onConnectivityChanged.listen(_apply);
    } catch (_) {}
  }

  static void _apply(List<ConnectivityResult> r) {
    _fast = r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  }

  static bool get isFast => _fast;

  /// Дар интернети суст (mobile) сифати паст, дар Wi-Fi/тез сифати баланд.
  static String pick(String high, String low) =>
      (!_fast && low.isNotEmpty) ? low : high;
}
