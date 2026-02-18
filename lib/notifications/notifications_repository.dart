import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  /// GET NOTIFICATIONS
  Future<List<NotificationModel>> fetchNotifications() async {
    final response =
        await ApiClient.get(ApiEndpoints.notifications);

    final List list = jsonDecode(response.body) as List;
    return list
        .map((e) => NotificationModel.fromJson(e))
        .toList();
  }

  /// MARK ONE AS READ
  Future<void> markAsRead(String notificationId) async {
    await ApiClient.post(
      '${ApiEndpoints.notifications}/$notificationId/read',
    );
  }

  /// MARK ALL AS READ
  Future<void> markAllAsRead() async {
    await ApiClient.post(
      '${ApiEndpoints.notifications}/read-all',
    );
  }
}
