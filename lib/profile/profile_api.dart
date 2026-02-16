import '../core/api.dart';
import 'dart:convert';

class ProfileApi {
  static Future<Map<String, dynamic>> fetch(String username) async {
    final res = await Api.get('/profile/$username');
    return jsonDecode(res.body);
  }
}
