import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';
import 'constants.dart';

class Api {
  static Future<http.Response> get(String path) async {
    final token = Session.token;
    return http.get(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = Session.token;
    return http.post(
      Uri.parse('${Constants.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }
}
