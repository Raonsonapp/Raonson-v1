import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class AuthRepository {
  final ApiClient _api = ApiClient.instance;

  // ================= LOGIN =================
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      ApiEndpoints.login,
      body: {
        'email': email,
        'password': password,
      },
    );

    return jsonDecode(res.body);
  }

  // ================= REGISTER =================
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      ApiEndpoints.register,
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    return jsonDecode(res.body);
  }

  // ================= REFRESH TOKEN =================
  Future<Map<String, dynamic>> refreshToken() async {
    final res = await _api.post(ApiEndpoints.refresh);
    return jsonDecode(res.body);
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _api.post(ApiEndpoints.logout);
  }

  // ================= PASSWORD =================
  /// Рамзи 6-рақамаро тавассути канали интихобшуда мефиристад.
  /// channel: 'email' | 'sms' | 'whatsapp'. Агар backend рамзро
  /// баргардонад (бе провайдер), онро бармегардонем (барои санҷиш).
  Future<String?> forgotPassword(String identifier, {String channel = 'email'}) async {
    final res = await _api.post(
      ApiEndpoints.forgotPassword,
      body: {'identifier': identifier, 'channel': channel},
    );
    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j['otp']?.toString();
    } catch (_) { return null; }
  }

  Future<bool> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final res = await _api.post(
      ApiEndpoints.resetPassword,
      body: {
        'identifier': identifier,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
    return res.statusCode < 400;
  }

  /// OTP-ро ба телефон тавассути Telegram мефиристад.
  Future<Map<String, dynamic>> sendPhoneOtp(String phone) async {
    final res = await _api.post(
      ApiEndpoints.sendPhoneOtp,
      body: {'phone': phone},
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// OTP-ро тасдиқ мекунад.
  Future<bool> verifyPhoneOtp(String phone, String otp) async {
    final res = await _api.post(
      ApiEndpoints.verifyPhoneOtp,
      body: {'phone': phone, 'otp': otp},
    );
    if (res.statusCode >= 400) return false;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return j['verified'] == true;
  }
}
