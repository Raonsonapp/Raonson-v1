import 'dart:convert';
import '../core/api/api_client.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> fetchNotifications() async {
    final res = await _api.get('/notifications');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['notifications'] as List? ?? [])
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return {
      'notifications': list,
      'unreadCount': data['unreadCount'] ?? 0,
    };
  }

  Future<void> markAsRead(String id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _api.post('/notifications/read-all');
  }
}
