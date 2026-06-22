import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/token_storage.dart';
import '../../core/services/user_session.dart';
import '../../core/services/account_manager.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';

class LoginState {
  final String email;
  final String password;
  final bool   isLoading;
  final String? error;

  const LoginState({
    required this.email,
    required this.password,
    required this.isLoading,
    this.error,
  });

  factory LoginState.initial() => const LoginState(
    email: '', password: '', isLoading: false);

  bool get canSubmit =>
      email.isNotEmpty && password.isNotEmpty && !isLoading;

  LoginState copyWith({
    String? email, String? password, bool? isLoading, String? error}) =>
    LoginState(
      email:     email     ?? this.email,
      password:  password  ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error:     error,
    );
}

class LoginController extends ChangeNotifier {
  LoginState _state = LoginState.initial();
  LoginState get state => _state;

  void updateEmail(String v)    { _state = _state.copyWith(email: v);    notifyListeners(); }
  void updatePassword(String v) { _state = _state.copyWith(password: v); notifyListeners(); }

  Future<bool> login() async {
    if (!_state.canSubmit) return false;
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'email':    _state.email.trim(),
          'password': _state.password,
        },
      );

      if (res.statusCode != 200) {
        Map body = {};
        try { body = jsonDecode(res.body); } catch (_) {}
        throw Exception(body['message'] ?? 'Login хато ${res.statusCode}');
      }

      final data  = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['accessToken']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Token нест');

      // Save token — мондагорӣ
      await TokenStorage.saveAccessToken(token);
      ApiClient.instance.setAuthToken(token);

      // Save refresh token if present
      final refresh = data['refreshToken']?.toString() ?? '';
      if (refresh.isNotEmpty) {
        await TokenStorage.saveRefreshToken(refresh);
      }

      // Save user info
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        final uid = (user['id'] ?? user['_id'])?.toString() ?? '';
        if (uid.isNotEmpty) {
          await TokenStorage.saveUserId(uid);
          UserSession.userId   = uid;
          UserSession.username = (user['username'] ?? '').toString();
          UserSession.avatar   = (user['avatar']   ?? '').toString();
          // Multi-account: аккаунтро сабт мекунем
          await AccountManager.upsertCurrent(
            userId: uid,
            username: (user['username'] ?? '').toString(),
            avatar: (user['avatar'] ?? '').toString(),
            token: token,
            refreshToken: refresh,
          );
        }
      }

      AnalyticsService.instance.logEvent(AnalyticsEvents.login);
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return true;

    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      notifyListeners();
      return false;
    }
  }
}
