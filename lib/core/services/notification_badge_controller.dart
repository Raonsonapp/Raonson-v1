// lib/core/services/notification_badge_controller.dart
//
// App-wide unread notification badge counter.
//
// - SocketService 'notification:new' → increment()
// - Opening / marking notifications read → reset() / setCount()
// - Bottom nav listens to this and shows the badge.
//
// Singleton ChangeNotifier so every widget that listens stays in sync.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

import 'socket_service.dart';

class NotificationBadgeController extends ChangeNotifier {
  NotificationBadgeController._();
  static final NotificationBadgeController instance =
      NotificationBadgeController._();

  int _count = 0;
  int get count => _count;

  bool _wired = false;

  /// Subscribe to the realtime 'notification:new' socket event exactly once.
  ///
  /// Сервер шумораи нахондашударо ҳамроҳ мефиристад (`unreadCount`) —
  /// он аз ҳисоби маҳаллӣ боэътимодтар аст: ҳамон обуна ду бор (бекор →
  /// дубора) як сатр аст, на ду. Агар набошад — танҳо +1.
  void wireSocket() {
    if (_wired) return;
    _wired = true;
    SocketService.instance.on('notification:new', onSocketEvent);
  }

  @visibleForTesting
  void onSocketEvent(dynamic data) {
    final n = data is Map ? data['unreadCount'] : null;
    if (n is num) {
      setCount(n.toInt());
    } else {
      increment();
    }
    onChanged?.call(_count);
  }

  /// Барои бейҷи дуюм (тугмаи дил дар лента) — то ҳарду якхела бошанд.
  static void Function(int count)? onChanged;

  /// Шумораро аз сервер мегирад (масалан, вақте push дар барномаи
  /// кушода омад). Хато — бетағйир.
  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance
          .get('/notifications/unread-count')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final b = jsonDecode(res.body);
      final c = b is Map ? (b['count'] ?? b['unreadCount']) : null;
      if (c is num) {
        setCount(c.toInt());
        onChanged?.call(_count);
      }
    } catch (_) {}
  }

  void setCount(int value) {
    final v = value < 0 ? 0 : value;
    if (v == _count) return;
    _count = v;
    notifyListeners();
  }

  void increment() {
    _count++;
    notifyListeners();
  }

  void decrement() {
    if (_count <= 0) return;
    _count--;
    notifyListeners();
  }

  void reset() {
    if (_count == 0) return;
    _count = 0;
    notifyListeners();
  }
}
