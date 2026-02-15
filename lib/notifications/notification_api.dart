import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'notification_model.dart';

class NotificationApi {
  // 📥 GET NOTIFICATIONS
  static Future<List<AppNotification>> fetch(String username) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/notifications/$username'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load notifications');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => AppNotification.fromJson(e)).toList();
  }

  // 👁 MARK AS SEEN
  static Future<void> markSeen(String id) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/notifications/$id/seen'),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
