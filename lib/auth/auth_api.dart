import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class AuthApi {
  static const _tokenKey = 'auth_token';

  /// 📤 SEND OTP (phone OR email)
  static Future<void> sendOtp(String value) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        value.contains('@') ? 'email' : 'phone': value,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to send OTP');
    }
  }

  /// ✅ VERIFY OTP
  static Future<String> verifyOtp({
    required String value,
    required String otp,
  }) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        value.contains('@') ? 'email' : 'phone': value,
        'otp': otp,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('OTP verification failed');
    }

    final data = jsonDecode(res.body);
    final token = data['token'];

    if (token == null) {
      throw Exception('Token missing');
    }

    await saveToken(token);
    return token;
  }

  /// 💾 SAVE TOKEN
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 📥 GET TOKEN
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 🚪 LOGOUT
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
