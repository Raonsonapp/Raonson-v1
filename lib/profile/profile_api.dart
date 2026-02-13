import '../core/api.dart';

class ProfileApi {
  static Future<void> follow(String userId) async {
    await Api.post('/follow/$userId');
  }
}
