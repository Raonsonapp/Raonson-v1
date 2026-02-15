import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Api {
  /// 👤 TOKEN (пас аз login мегирем)
  static String? token;

  /// 📦 HEADER (худкор)
  static Map<String, String> headers() {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 📥 GET
  static Future<http.Response> get(String path) {
    return http.get(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: headers(),
    );
  }

  /// 📤 POST
  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return http.post(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: headers(),
      body: body == null ? null : jsonEncode(body),
    );
  }
}
