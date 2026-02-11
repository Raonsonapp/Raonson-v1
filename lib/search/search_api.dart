import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'search_model.dart';

class SearchApi {
  static Future<Map<String, dynamic>> search(String q) async {
    final token = await TokenStorage.read();

    final res = await http.get(
      Uri.parse('${Api.baseUrl}/search?q=$q'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(res.body);
    return {
      'users': (data['users'] as List)
          .map((e) => SearchUser.fromJson(e))
          .toList(),
      'posts': (data['posts'] as List)
          .map((e) => SearchPost.fromJson(e))
          .toList(),
    };
  }
}
