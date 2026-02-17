import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import 'auth_repository.dart';

class AuthService {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  AuthService(this._repository, this._tokenStorage);

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final data = await _repository.login(
      username: username,
      password: password,
    );

    if (!data.containsKey('token')) {
      throw Exception('Token missing');
    }

    await _tokenStorage.saveToken(data['token']);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await _repository.register(
      username: username,
      email: email,
      password: password,
    );

    if (data.containsKey('token')) {
      await _tokenStorage.saveToken(data['token']);
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<void> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token != null) {
      ApiClient.instance.setAuthToken(token);
    }
  }

  Future<void> refreshSession() async {
    final data = await _repository.refreshToken();
    if (!data.containsKey('token')) {
      throw Exception('Refresh failed');
    }

    await _tokenStorage.saveToken(data['token']);
    ApiClient.instance.setAuthToken(data['token']);
  }

  Future<void> forgotPassword(String email) {
    return _repository.forgotPassword(email);
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _repository.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }
}
