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
    final response = await _api.postRequest(
      ApiEndpoints.login,
      body: {
        'email': email,
        'password': password,
      },
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ================= REGISTER =================
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _api.postRequest(
      ApiEndpoints.register,
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ================= REFRESH TOKEN =================
  Future<Map<String, dynamic>> refreshToken() async {
    final response = await _api.postRequest(
      ApiEndpoints.refresh,
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _api.postRequest(ApiEndpoints.logout);
  }

  // ================= FORGOT PASSWORD =================
  Future<void> forgotPassword(String email) async {
    await _api.postRequest(
      ApiEndpoints.forgotPassword,
      body: {
        'email': email,
      },
    );
  }

  // ================= RESET PASSWORD =================
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _api.postRequest(
      ApiEndpoints.resetPassword,
      body: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
  }
}
