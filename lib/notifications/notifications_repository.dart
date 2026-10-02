import 'dart:convert';
import '../core/api/api_client.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient.instance;

  /// Андозаи саҳифа — пешфарзи сервер (GetNotifications).
  static const pageSize = 30;

  Future<Map<String, dynamic>> fetchNotifications({int page = 1}) async {
    final res = await _api.get('/notifications',
        query: {'page': '$page', 'limit': '$pageSize'});
    // Пеш хатои сервер (401/500) ҳамчун «огоҳинома нест» нишон дода мешуд.
    if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);
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
