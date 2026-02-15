import '../core/api.dart';

class NotificationApi {
  static Future<List<dynamic>> fetch() async {
    final res = await Api.get('/notifications?user=raonson');
    return res;
  }

  static Future<void> markSeen() async {
    await Api.post('/notifications/seen', body: {
      'user': 'raonson',
    });
  }
}
