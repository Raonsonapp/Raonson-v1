import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

/// ---------------------------
/// STATE
/// ---------------------------
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

/// ---------------------------
/// CONTROLLER
/// ---------------------------
class RegisterController extends ChangeNotifier {
  RegisterState _state = RegisterState.initial();
  RegisterState get state => _state;

  /// 🔹 update username
  void updateUsername(String value) {
    _state = _state.copyWith(username: value);
    notifyListeners();
  }

  /// 🔹 update email
  void updateEmail(String value) {
    _state = _state.copyWith(email: value);
    notifyListeners();
  }

  /// 🔹 update password
  void updatePassword(String value) {
    _state = _state.copyWith(password: value);
    notifyListeners();
  }

  /// 🔹 update confirm password
  void updateConfirmPassword(String value) {
    _state = _state.copyWith(confirmPassword: value);
    notifyListeners();
  }

  /// 🔹 register action
  Future<void> register() async {
    if (_state.isLoading) return;

    if (_state.password != _state.confirmPassword) {
      _state = _state.copyWith(
        error: 'Passwords do not match',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.post(
        ApiEndpoints.register,
        body: {
          'username': _state.username.trim(),
          'email': _state.email.trim(),
          'password': _state.password,
        },
      );

      jsonDecode(response.body);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }
}
