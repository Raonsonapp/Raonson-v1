import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Api {
  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(res.body);
  }

  static Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body ?? {}),
    );
    return jsonDecode(res.body);
  }
}
