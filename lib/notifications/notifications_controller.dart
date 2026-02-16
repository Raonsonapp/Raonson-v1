import 'package:flutter/material.dart';
import '../core/socket_service.dart';
import 'notification_model.dart';

class NotificationsController extends ChangeNotifier {
  final List<AppNotification> _items = [];
  int unread = 0;

  List<AppNotification> get items => _items;

  void init(String userId) {
    final socket = SocketService();
    socket.connect(userId);

    socket.on('notification', (data) {
      final n = AppNotification.fromJson(data);
      _items.insert(0, n);
      unread++;
      notifyListeners();
    });
  }

  void markAllSeen() {
    unread = 0;
    notifyListeners();
  }
}
