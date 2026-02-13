import 'dart:convert';
import '../core/api.dart';

class ProfileApi {
  static Future<Map<String, dynamic>> getProfile(String userId) async {
    final res = await Api.get('/profile/$userId');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Profile load failed');
  }

  static Future<void> follow(String userId) async {
    await Api.post('/follow/$userId');
  }
}
