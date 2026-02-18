import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class AuthRepository {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.postRequest(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _api.postRequest(
      ApiEndpoints.register,
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final res = await _api.postRequest(ApiEndpoints.refresh);
    return jsonDecode(res.body);
  }

  Future<void> logout() {
    return _api.postRequest(ApiEndpoints.logout);
  }

  Future<void> forgotPassword(String email) {
    return _api.postRequest(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _api.postRequest(
      ApiEndpoints.resetPassword,
      body: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
  }
}
