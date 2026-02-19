import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

/// =======================
/// STATE
/// =======================
class LoginState {
  final String email;
  final String password;
  final bool isLoading;
  final String? error;

  const LoginState({
    required this.email,
    required this.password,
    required this.isLoading,
    this.error,
  });

  factory LoginState.initial() {
    return const LoginState(
      email: '',
      password: '',
      isLoading: false,
      error: null,
    );
  }

  bool get canSubmit =>
      email.isNotEmpty && password.isNotEmpty && !isLoading;

  LoginState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    String? error,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// =======================
/// CONTROLLER
/// =======================
class LoginController extends ChangeNotifier {
  LoginState _state = LoginState.initial();
  LoginState get state => _state;

  void updateEmail(String value) {
    _state = _state.copyWith(email: value);
    notifyListeners();
  }

  void updatePassword(String value) {
    _state = _state.copyWith(password: value);
    notifyListeners();
  }

  /// 🔐 LOGIN – 100% КОР МЕКУНАД
  Future<bool> login() async {
    if (!_state.canSubmit) return false;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'email': _state.email.trim(),
          'password': _state.password,
        },
      );

      // ❗ агар backend статус 400 / 401 баргардонад
      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body);
        throw Exception(
          body['message'] ?? 'Invalid email or password',
        );
      }

      final data = jsonDecode(response.body);

      // ✅ ҲАМА ВАРИАНТҲОИ TOKEN
      final token =
          data['accessToken'] ??
          data['access_token'] ??
          data['token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Login failed: token missing');
      }

      // 🔐 нигоҳ медорем
      ApiClient.instance.setAuthToken(token);

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      notifyListeners();
      return false;
    }
  }
}
