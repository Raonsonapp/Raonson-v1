import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/token_storage.dart';
import '../../core/services/user_session.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';

class RegisterState {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;
  final bool   isLoading;
  final String? error;

  const RegisterState({
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.isLoading,
    this.error,
  });

  factory RegisterState.initial() => const RegisterState(
    username: '', email: '', password: '',
    confirmPassword: '', isLoading: false);

  bool get canSubmit =>
      username.isNotEmpty && email.isNotEmpty &&
      password.isNotEmpty && password == confirmPassword && !isLoading;

  RegisterState copyWith({
    String? username, String? email, String? password,
    String? confirmPassword, bool? isLoading, String? error}) =>
    RegisterState(
      username:        username        ?? this.username,
      email:           email           ?? this.email,
      password:        password        ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isLoading:       isLoading       ?? this.isLoading,
      error:           error,
    );
}

class RegisterController extends ChangeNotifier {
  RegisterState _state = RegisterState.initial();
  RegisterState get state => _state;

  void updateUsername(String v)        { _state = _state.copyWith(username: v);        notifyListeners(); }
  void updateEmail(String v)           { _state = _state.copyWith(email: v);           notifyListeners(); }
  void updatePassword(String v)        { _state = _state.copyWith(password: v);        notifyListeners(); }
  void updateConfirmPassword(String v) { _state = _state.copyWith(confirmPassword: v); notifyListeners(); }

  Future<bool> register() async {
    if (!_state.canSubmit) return false;
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      // 1. Register
      final res = await ApiClient.instance.post(
        ApiEndpoints.register,
        body: {
          'username': _state.username.trim(),
          'email':    _state.email.trim(),
          'password': _state.password,
        },
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        Map body = {};
        try { body = jsonDecode(res.body); } catch (_) {}
        throw Exception(body['message'] ?? 'Рӯйхат нашуд ${res.statusCode}');
      }

      // 2. Auto-login after register
      final loginRes = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'email':    _state.email.trim(),
          'password': _state.password,
        },
      );

      if (loginRes.statusCode == 200) {
        final data  = jsonDecode(loginRes.body) as Map<String, dynamic>;
        final token = data['accessToken']?.toString() ?? '';
        if (token.isNotEmpty) {
          // Save token permanently
          await TokenStorage.saveAccessToken(token);
          ApiClient.instance.setAuthToken(token);

          final refresh = data['refreshToken']?.toString() ?? '';
          if (refresh.isNotEmpty) {
            await TokenStorage.saveRefreshToken(refresh);
            ApiClient.instance.setRefreshToken(refresh);
          }

          final user = data['user'] as Map<String, dynamic>?;
          if (user != null) {
            final uid = (user['id'] ?? user['_id'])?.toString() ?? '';
            if (uid.isNotEmpty) {
              await TokenStorage.saveUserId(uid);
              UserSession.userId   = uid;
              UserSession.username = (user['username'] ?? '').toString();
              UserSession.avatar   = (user['avatar']   ?? '').toString();
            }
          }
        }
      }

      AnalyticsService.instance.logEvent(AnalyticsEvents.register);
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
