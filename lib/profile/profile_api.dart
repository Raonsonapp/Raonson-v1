import 'dart:convert';
import '../core/api.dart';

class ProfileApi {
  static Future<Map<String, dynamic>> fetch(String userId) async {
    final res = await Api.get('/profile/$userId');
    return jsonDecode(res.body);
  }

  static Future<bool> follow(String userId) async {
    final res = await Api.post('/profile/$userId/follow', {});
    return jsonDecode(res.body)['following'];
  }
}
