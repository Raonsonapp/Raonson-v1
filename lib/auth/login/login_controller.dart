import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../app/app_state.dart';

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

  void updateUsername(String value) {
    _state = _state.copyWith(email: value);
    notifyListeners();
  }

  void updatePassword(String value) {
    _state = _state.copyWith(password: value);
    notifyListeners();
  }

  Future<void> login(BuildContext context) async {
    if (_state.isLoading) return;

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

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final token = data['accessToken'];
      if (token == null) {
        throw Exception('Access token missing');
      }

      // 🔐 save token
      ApiClient.instance.setAuthToken(token);

      // ✅ AUTO LOGIN → HOME
      context.read<AppState>().login();

    } catch (e) {
      _state = _state.copyWith(error: e.toString());
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }
}
