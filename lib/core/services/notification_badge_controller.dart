// lib/core/services/notification_badge_controller.dart
//
// App-wide unread notification badge counter.
//
// - SocketService 'notification:new' → increment()
// - Opening / marking notifications read → reset() / setCount()
// - Bottom nav listens to this and shows the badge.
//
// Singleton ChangeNotifier so every widget that listens stays in sync.
import 'package:flutter/foundation.dart';

import 'socket_service.dart';

class NotificationBadgeController extends ChangeNotifier {
  NotificationBadgeController._();
  static final NotificationBadgeController instance =
      NotificationBadgeController._();

  int _count = 0;
  int get count => _count;

  bool _wired = false;

  /// Subscribe to the realtime 'notification:new' socket event exactly once.
  void wireSocket() {
    if (_wired) return;
    _wired = true;
    SocketService.instance.on('notification:new', (_) => increment());
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
