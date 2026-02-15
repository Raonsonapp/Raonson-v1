import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationApi {
  static const baseUrl = 'https://YOUR_RENDER_URL';

  static Future<List<dynamic>> fetchForUser(String user) async {
    final res = await http.get(Uri.parse('$baseUrl/notifications/$user'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load notifications');
  }

  static Future<void> markSeen(String id) async {
    await http.post(Uri.parse('$baseUrl/notifications/$id/seen'));
  }
}
