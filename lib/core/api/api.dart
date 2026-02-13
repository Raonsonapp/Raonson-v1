import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const String baseUrl =
      "https://raonson-v1.onrender.com";

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body ?? {}),
    );

    return jsonDecode(res.body);
  }
}
