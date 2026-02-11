import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'auth_model.dart';

class AuthApi {
  static Future<AuthResult?> login(
      String phone, String password) async {
    final res = await http.post(
      Uri.parse('${Api.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    final result = AuthResult.fromJson(data);

    await TokenStorage.save(result.token);
    return result;
  }
}
