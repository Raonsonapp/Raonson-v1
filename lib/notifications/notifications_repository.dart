import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient.instance;

  // ================= GET NOTIFICATIONS =================
  Future<List<NotificationModel>> fetchNotifications() async {
    final response = await _api.getRequest(
      ApiEndpoints.notifications,
    );

    final List list = jsonDecode(response.body) as List;
    return list
        .map((e) => NotificationModel.fromJson(e))
        .toList();
  }

  // ================= MARK ONE AS READ =================
  Future<void> markAsRead(String notificationId) async {
    await _api.postRequest(
      '${ApiEndpoints.notifications}/$notificationId/read',
    );
  }

  // ================= MARK ALL AS READ =================
  Future<void> markAllAsRead() async {
    await _api.postRequest(
      '${ApiEndpoints.notifications}/read-all',
    );
  }
}
