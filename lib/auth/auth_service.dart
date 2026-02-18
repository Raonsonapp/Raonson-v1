import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import 'auth_repository.dart';

class AuthService {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  AuthService(this._repository, this._tokenStorage);

  // ================= LOGIN =================
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await _repository.login(
      email: email,
      password: password,
    );

    final accessToken = data['accessToken'];
    if (accessToken == null) {
      throw Exception('Access token missing');
    }

    await _tokenStorage.saveToken(accessToken);
    ApiClient.instance.setAuthToken(accessToken);
  }

  // ================= REGISTER =================
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

    final accessToken = data['accessToken'];
    if (accessToken != null) {
      await _tokenStorage.saveToken(accessToken);
      ApiClient.instance.setAuthToken(accessToken);
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await _repository.logout();
    await _tokenStorage.clear();
    ApiClient.instance.setAuthToken(null);
  }

  // ================= RESTORE =================
  Future<void> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token != null) {
      ApiClient.instance.setAuthToken(token);
    }
  }

  // ================= REFRESH =================
  Future<void> refreshSession() async {
    final data = await _repository.refreshToken();

    final accessToken = data['accessToken'];
    if (accessToken == null) {
      throw Exception('Refresh failed');
    }

    await _tokenStorage.saveToken(accessToken);
    ApiClient.instance.setAuthToken(accessToken);
  }
}
