import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class NotificationApi {
  // GET NOTIFICATIONS
  static Future<List<dynamic>> fetchNotifications() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/notifications'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load notifications');
    }

    return jsonDecode(res.body);
  }

  // MARK AS SEEN
  static Future<void> markSeen(String id) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/notifications/$id/seen'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to mark notification seen');
    }
  }
}
