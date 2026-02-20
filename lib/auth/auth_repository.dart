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
  Future<void> forgotPassword(String email) async {
    await _api.post(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post(
      ApiEndpoints.resetPassword,
      body: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
  }
}
