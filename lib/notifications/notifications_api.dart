import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'notification_model.dart';

class NotificationApi {
  static Future<List<AppNotification>> fetch(String user) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/notifications?user=$user'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load notifications');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => AppNotification.fromJson(e)).toList();
  }

  static Future<void> markSeen(String id) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/notifications/$id/seen'),
    );
  }
}
