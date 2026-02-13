import '../core/api.dart';

class NotificationsApi {
  static Future<List<dynamic>> getNotifications() async {
    final res = await Api.get('/notifications');
    return res as List<dynamic>;
  }
}
