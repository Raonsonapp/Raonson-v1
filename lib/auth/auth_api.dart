import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';

class AuthApi {
  static Future<String?> login(String phone, String password) async {
    final res = await http.post(
      Uri.parse('${Api.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['token'];
    }
    return null;
  }
}
