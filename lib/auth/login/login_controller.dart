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
  }) =>
      LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
        isLoading: isLoading ?? this.isLoading,
        isWakingServer: isWakingServer ?? this.isWakingServer,
        error: error,
      );
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

  // Try to POST login. Returns response or throws.
  Future<Map<String, dynamic>> _attemptLogin() async {
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
        body is Map ? (body['message'] ?? 'Login failed') : 'Login failed',
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> login() async {
    if (!_state.canSubmit) return false;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      Map<String, dynamic> data;

      try {
        // First attempt - may fail if server is cold
        data = await _attemptLogin();
      } catch (e) {
        // If timeout or connection error, wake server and retry
        final isConnErr = e.toString().contains('Timeout') ||
            e.toString().contains('timeout') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection');

        if (!isConnErr) rethrow; // wrong password etc - don't retry

        // Show waking banner and wait for server
        _state = _state.copyWith(isWakingServer: true);
        notifyListeners();

        try {
          await ApiClient.instance
              .get('/health')
              .timeout(const Duration(seconds: 90));
        } catch (_) {}

        _state = _state.copyWith(isWakingServer: false);
        notifyListeners();

        // Second attempt after wake
        data = await _attemptLogin();
      }

      final token = data['accessToken'];
      if (token == null || token.toString().isEmpty) {
        throw Exception('Access token missing');
      }

      await TokenStorage.saveAccessToken(token.toString());
      ApiClient.instance.setAuthToken(token);

      final user = data['user'] as Map<String, dynamic>?;
      if (user != null) {
        UserSession.userId = (user['id'] ?? user['_id'])?.toString();
        UserSession.username = user['username']?.toString();
      }

      _state = _state.copyWith(isLoading: false, isWakingServer: false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Login] error: \$e');
      _state = _state.copyWith(
        isLoading: false,
        isWakingServer: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      notifyListeners();
      return false;
    }
  }
}
