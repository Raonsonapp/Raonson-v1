import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/token_storage.dart';
import '../../core/services/user_session.dart';

class LoginState {
  final String email;
  final String password;
  final bool isLoading;
  final bool isWakingServer;
  final String? error;

  const LoginState({
    required this.email,
    required this.password,
    required this.isLoading,
    this.isWakingServer = false,
    this.error,
  });

  factory LoginState.initial() => const LoginState(
        email: '',
        password: '',
        isLoading: false,
      );

  bool get canSubmit =>
      email.isNotEmpty && password.isNotEmpty && !isLoading;

  LoginState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    bool? isWakingServer,
    String? error,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      isWakingServer: isWakingServer ?? this.isWakingServer,
      error: error,
    );
  }
}

class LoginController extends ChangeNotifier {
  LoginState _state = LoginState.initial();
  LoginState get state => _state;

  void updateEmail(String v) {
    _state = _state.copyWith(email: v);
    notifyListeners();
  }

  void updatePassword(String v) {
    _state = _state.copyWith(password: v);
    notifyListeners();
  }

  // Wake up Render server before login (cold start can take 50-60s)
  Future<void> _wakeServer() async {
    try {
      _state = _state.copyWith(isWakingServer: true);
      notifyListeners();
      await ApiClient.instance
          .get('/health')
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      // ignore - server may already be awake or timeout is fine
    } finally {
      _state = _state.copyWith(isWakingServer: false);
      notifyListeners();
    }
  }

  Future<bool> login() async {
    if (!_state.canSubmit) return false;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      // Step 1: ping server to wake it up on Render free tier
      await _wakeServer();

      // Step 2: actual login
      final res = await ApiClient.instance
          .post(
            ApiEndpoints.login,
            body: {
              'email': _state.email.trim(),
              'password': _state.password,
            },
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        dynamic body;
        try { body = jsonDecode(res.body); } catch (_) {}
        throw Exception(
          body is Map<String, dynamic>
              ? (body['message'] ?? 'Login failed')
              : 'Login failed',
        );
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['accessToken'];
      if (token == null || token.toString().isEmpty) {
        throw Exception('Access token missing');
      }

      await TokenStorage.saveAccessToken(token.toString());
      ApiClient.instance.setAuthToken(token);

      // Set UserSession for isMine logic in chat
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        UserSession.userId = (user['id'] ?? user['_id'])?.toString();
        UserSession.username = user['username']?.toString();
      }

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Login] error: $e');
      _state = _state.copyWith(
        isLoading: false,
        isWakingServer: false,
        error: e.toString().contains('TimeoutException')
            ? 'Server is starting up, please try again'
            : e.toString().replaceAll('Exception:', '').trim(),
      );
      notifyListeners();
      return false;
    }
  }
}
