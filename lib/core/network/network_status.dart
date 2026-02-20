import 'dart:async';
import 'dart:io';

class NetworkStatus {
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  static Stream<bool> get statusStream => _controller.stream;

  static Future<void> startMonitoring({
    Duration interval = const Duration(seconds: 5),
  }) async {
    Timer.periodic(interval, (_) async {
      final connected = await _hasInternet();
      _controller.add(connected);
    });
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static void dispose() {
    _controller.close();
  }
}
