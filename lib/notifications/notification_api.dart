import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import 'notification_model.dart';

class NotificationApi {
  /// GET notifications for user
  static Future<List<AppNotification>> fetch(String user) async {
    final res = await Api.get('/notifications/$user');

    final List list = jsonDecode(res.body);
    return list.map((e) => AppNotification.fromJson(e)).toList();
  }

  /// MARK notification as seen
  static Future<void> markSeen(String id) async {
    await Api.post('/notifications/$id/seen');
  }
}
