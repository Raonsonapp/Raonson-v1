import '../core/api.dart';
import 'dart:convert';

class ExploreApi {
  static Future<Map<String, dynamic>> fetch() async {
    final res = await Api.get('/explore');
    return jsonDecode(res.body);
  }
}
