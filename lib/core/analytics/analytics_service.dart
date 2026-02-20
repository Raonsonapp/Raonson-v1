import 'dart:developer';

class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService instance =
      AnalyticsService._internal();

  bool _enabled = true;

  void enable() {
    _enabled = true;
  }

  void disable() {
    _enabled = false;
  }

  void logEvent(
    String event, {
    Map<String, dynamic>? params,
  }) {
    if (!_enabled) return;

    final payload = {
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      if (params != null) 'params': params,
    };

    _send(payload);
  }

  void logScreen(String screenName) {
    logEvent(
      'screen_view',
      params: {'screen': screenName},
    );
  }

  void setUser(String userId) {
    if (!_enabled) return;

    _send({
      'event': 'set_user',
      'userId': userId,
    });
  }

  void clearUser() {
    if (!_enabled) return;

    _send({
      'event': 'clear_user',
    });
  }

  void _send(Map<String, dynamic> data) {
    // ⛔ No vendor lock-in here
    // 👉 Later can be piped to Firebase, Segment, backend, etc.
    log('[ANALYTICS] ${data.toString()}');
  }
}
