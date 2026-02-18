import '../core/storage/token_storage.dart';
import 'auth_repository.dart';

class AuthService {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  AuthService(
    this._repository,
    this._tokenStorage,
  );

  // ================= LOGIN =================
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await _repository.login(
      email: email,
      password: password,
    );

    final token = data['token'];
    if (token == null) {
      throw Exception('Token missing in login response');
    }

    await _tokenStorage.saveToken(token);
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

    final token = data['token'];
    if (token != null) {
      await _tokenStorage.saveToken(token);
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      await _tokenStorage.clear();
    }
  }

  // ================= RESTORE SESSION =================
  Future<bool> restoreSession() async {
    final token = await _tokenStorage.getToken();
    return token != null;
  }

  // ================= REFRESH TOKEN =================
  Future<void> refreshSession({
    required String refreshToken,
  }) async {
    final data = await _repository.refreshToken(
      refreshToken: refreshToken,
    );

    final token = data['token'];
    if (token == null) {
      throw Exception('Refresh token failed');
    }

    await _tokenStorage.saveToken(token);
  }
}
