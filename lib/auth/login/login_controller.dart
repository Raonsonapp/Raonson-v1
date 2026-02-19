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
      email.trim().isNotEmpty &&
      password.isNotEmpty &&
      !isLoading;

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
    _state = _state.copyWith(
      email: value,
      error: null,
    );
    notifyListeners();
  }

  void updatePassword(String value) {
    _state = _state.copyWith(
      password: value,
      error: null,
    );
    notifyListeners();
  }

  /// ==================================================
  /// 🔐 LOGIN
  /// return true  -> SUCCESS
  /// return false -> ERROR (spinner ҲАМЕША қатъ мешавад)
  /// ==================================================
  Future<bool> login() async {
    if (!_state.canSubmit) return false;

    // START LOADING
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'email': _state.email.trim().toLowerCase(),
          'password': _state.password,
        },
      );

      // ❗ Агар backend хато фиристад
      if (response.statusCode != 200) {
        throw Exception('Invalid credentials');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final token =
          data['accessToken'] ?? data['token'] ?? data['access_token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Access token missing');
      }

      // SAVE TOKEN IN MEMORY
      ApiClient.instance.setAuthToken(token.toString());

      // STOP LOADING
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      return true;
    } catch (e) {
      // ❌ ERROR — ҲЕҶ ГОҲ spinner намемонад
      _state = _state.copyWith(
        isLoading: false,
        error: 'Invalid email or password',
      );
      notifyListeners();
      return false;
    }
  }
}
