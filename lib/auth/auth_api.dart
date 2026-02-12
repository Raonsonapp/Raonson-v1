import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';

class AuthApi {
  static Future<void> login(String email, String password) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
  }
}
