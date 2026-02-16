import '../core/api.dart';
import 'dart:convert';

class SearchApi {
  static Future<List<dynamic>> users(String q) async {
    final res = await Api.get('/search/users?q=$q');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> posts(String q) async {
    final res = await Api.get('/search/posts?q=$q');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> reels() async {
    final res = await Api.get('/search/reels');
    return jsonDecode(res.body);
  }
}
