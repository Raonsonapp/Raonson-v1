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

  Future<void> login() async {
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

      if (!data.containsKey('token')) {
        throw Exception('Token missing');
      }
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }
}
