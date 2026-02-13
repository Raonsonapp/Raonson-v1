import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Api {
  static Future<http.Response> get(String path) {
    return http.get(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return http.post(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
  }
}
