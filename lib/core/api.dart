import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'session.dart';

class Api {
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) {
    return http.post(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (Session.token != null)
          'Authorization': 'Bearer ${Session.token}',
      },
      body: jsonEncode(body),
    );
  }
}
