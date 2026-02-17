import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  final ApiClient _api = ApiClient.instance;

  /// =========================
  /// GET ALL NOTIFICATIONS
  /// =========================
  Future<List<NotificationModel>> fetchNotifications() async {
    final response = await _api.get(ApiEndpoints.notifications);

    final List list = response.data as List;
    return list.map((e) => NotificationModel.fromJson(e)).toList();
  }

  /// =========================
  /// MARK AS READ
  /// =========================
  Future<void> markAsRead(String notificationId) async {
    await _api.post(
      ApiEndpoints.markNotificationRead(notificationId),
    );
  }

  /// =========================
  /// MARK ALL AS READ
  /// =========================
  Future<void> markAllAsRead() async {
    await _api.post(ApiEndpoints.markAllNotificationsRead);
  }
}
