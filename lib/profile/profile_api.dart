import 'dart:convert';
import '../core/api.dart';

class ProfileApi {
  /// GET /profile/:userId
  static Future<Map<String, dynamic>> getProfile(String userId) async {
    final res = await Api.get('/profile/$userId');
    return jsonDecode(res.body);
  }

  /// POST /follow/:userId
  static Future<void> follow(String userId) async {
    await Api.post('/follow/$userId');
  }
}
