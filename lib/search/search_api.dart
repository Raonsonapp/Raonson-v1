import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';

class SearchApi {
  static Future<List<dynamic>> search(String q) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/search?q=$q'),
    );

    return jsonDecode(res.body);
  }
}
