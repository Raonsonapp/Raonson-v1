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
    final response = await _api.post(
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
    final response = await _api.post(
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
  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await _api.post(
      ApiEndpoints.refreshToken,
      body: {
        'refreshToken': refreshToken,
      },
    );

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _api.post(ApiEndpoints.logout);
  }
}
