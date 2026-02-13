import 'dart:convert';
import '../core/api.dart';

class SearchApi {
  static Future<Map<String, dynamic>> search(String q) async {
    final res = await Api.get('/search?q=$q');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Search failed');
  }
}
