import '../core/api.dart';
import 'dart:convert';

class FeedApi {
  static Future<List<dynamic>> getFeed() async {
    final res = await Api.get('/feed');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Feed error');
  }
}
