import '../core/api/api_client.dart';

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _api.post(
      '/auth/login',
      body: {
        'username': username,
        'password': password,
      },
    );
    return res;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      '/auth/register',
      body: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
    return res;
  }

  Future<void> logout() async {
    await _api.post('/auth/logout');
  }

  Future<void> forgotPassword(String email) async {
    await _api.post(
      '/auth/forgot-password',
      body: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/reset-password',
      body: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final res = await _api.post('/auth/refresh');
    return res;
  }
}
