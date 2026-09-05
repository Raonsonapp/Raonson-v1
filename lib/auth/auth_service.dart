import '../core/api/api_client.dart';
import '../core/firebase_init.dart';
import '../core/storage/token_storage.dart';
import 'auth_repository.dart';
import '../core/services/user_session.dart';

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

    final refreshToken = data['refreshToken']?.toString();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await TokenStorage.saveRefreshToken(refreshToken);
      ApiClient.instance.setRefreshToken(refreshToken);
    }

    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      final uid = (user['id'] ?? user['_id'] ?? '').toString();
      if (uid.isNotEmpty) {
        await TokenStorage.saveUserId(uid);
        UserSession.userId   = uid;
        UserSession.username = (user['username'] ?? '').toString();
        UserSession.avatar   = (user['avatar']   ?? '').toString();
      }
    }
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
    if (accessToken == null) {
      throw Exception('Access token missing');
    }

    await _tokenStorage.saveToken(accessToken);
    ApiClient.instance.setAuthToken(accessToken);

    final refreshToken = data['refreshToken']?.toString();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await TokenStorage.saveRefreshToken(refreshToken);
      ApiClient.instance.setRefreshToken(refreshToken);
    }

    final user = data['user'] as Map<String, dynamic>?;
    if (user != null) {
      final uid = (user['id'] ?? user['_id'] ?? '').toString();
      if (uid.isNotEmpty) {
        await TokenStorage.saveUserId(uid);
        UserSession.userId   = uid;
        UserSession.username = (user['username'] ?? '').toString();
        UserSession.avatar   = (user['avatar']   ?? '').toString();
      }
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    // Токени дастгоҳ пеш аз ҳама пок мешавад: вагарна огоҳиномаҳои
    // ин корбар ба ҳамон телефон мерафтанд, ки касе дигар онро
    // истифода мебарад.
    await FirebaseInit.clearToken();
    await _repository.logout();
    await _tokenStorage.clear();
    ApiClient.instance.setAuthToken(null);
    ApiClient.instance.setRefreshToken(null);
    UserSession.clear();
  }

  // ================= RESTORE =================
  Future<void> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token != null) {
      ApiClient.instance.setAuthToken(token);
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        ApiClient.instance.setRefreshToken(refreshToken);
      }
      final uid = await TokenStorage.getUserId();
      if (uid != null && uid.isNotEmpty) {
        UserSession.userId = uid;
      }
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
