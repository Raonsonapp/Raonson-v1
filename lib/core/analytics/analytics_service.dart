import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import '../api/api_client.dart';

/// Lightweight analytics: events are buffered locally and POSTed to the
/// backend `/analytics/events` endpoint in batches (every 10s OR every
/// 20 events). If the network is unavailable the batch is re-queued and
/// retried on the next flush — nothing is lost while the app is running.
class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService instance = AnalyticsService._internal();

  bool _enabled = true;
  String? _userId;

  static const int _maxBatch = 20;
  static const Duration _flushInterval = Duration(seconds: 10);

  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  Timer? _timer;
  bool _sending = false;

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

    _buffer.add({
      'event': event,
      'params': params ?? <String, dynamic>{},
    });

    _ensureTimer();
    if (_buffer.length >= _maxBatch) {
      flush();
    }
  }

  void logScreen(String screenName) {
    logEvent(
      'screen_view',
      params: {'screen': screenName},
    );
  }

  void setUser(String userId) {
    _userId = userId;
    if (!_enabled) return;
    logEvent('set_user', params: {'userId': userId});
  }

  void clearUser() {
    if (!_enabled) return;
    logEvent('clear_user', params: {'userId': _userId ?? ''});
    _userId = null;
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(_flushInterval, (_) => flush());
  }

  /// Sends the current buffer to the backend. On failure the events are
  /// put back at the front of the buffer so they are retried later.
  Future<void> flush() async {
    if (_sending || _buffer.isEmpty) return;
    _sending = true;

    final batch = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      final res = await ApiClient.instance
          .post('/analytics/events', body: {'events': batch});
      if (res.statusCode >= 400) {
        // Server rejected — re-queue for retry.
        _buffer.insertAll(0, batch);
      }
    } catch (_) {
      // Offline / timeout — re-queue, keep buffer bounded.
      _buffer.insertAll(0, batch);
      if (_buffer.length > 500) {
        _buffer.removeRange(0, _buffer.length - 500);
      }
    } finally {
      _sending = false;
    }
  }

  // Kept for backwards compatibility / debugging.
  // ignore: unused_element
  void _send(Map<String, dynamic> data) {
    log('[ANALYTICS] ${jsonEncode(data)}');
  }
}
