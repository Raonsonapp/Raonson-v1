import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../app/app_state.dart';

class RegisterState {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;
  final bool isLoading;
  final String? error;

  const RegisterState({
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.isLoading,
    this.error,
  });

  factory RegisterState.initial() {
    return const RegisterState(
      username: '',
      email: '',
      password: '',
      confirmPassword: '',
      isLoading: false,
    );
  }

  bool get canSubmit =>
      username.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty &&
      password == confirmPassword &&
      !isLoading;

  RegisterState copyWith({
    String? username,
    String? email,
    String? password,
    String? confirmPassword,
    bool? isLoading,
    String? error,
  }) {
    return RegisterState(
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RegisterController extends ChangeNotifier {
  RegisterState _state = RegisterState.initial();
  RegisterState get state => _state;

  void updateUsername(String v) {
    _state = _state.copyWith(username: v);
    notifyListeners();
  }

  void updateEmail(String v) {
    _state = _state.copyWith(email: v);
    notifyListeners();
  }

  void updatePassword(String v) {
    _state = _state.copyWith(password: v);
    notifyListeners();
  }

  void updateConfirmPassword(String v) {
    _state = _state.copyWith(confirmPassword: v);
    notifyListeners();
  }

  Future<void> register(BuildContext context) async {
    if (!_state.canSubmit) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.register,
        body: {
          'username': _state.username.trim(),
          'email': _state.email.trim(),
          'password': _state.password,
        },
      );

      final data = jsonDecode(res.body);

      final token = data['accessToken'];
      if (token == null) {
        throw Exception('Access token missing');
      }

      // 🔐 set token
      ApiClient.instance.setAuthToken(token);

      // ✅ AUT0 LOGIN
      context.read<AppState>().login();

    } catch (e) {
      _state = _state.copyWith(error: e.toString());
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }
}
