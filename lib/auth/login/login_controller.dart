import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

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

class LoginController extends ChangeNotifier {
  LoginState _state = LoginState.initial();
  LoginState get state => _state;

  void updateUsername(String v) {
    _state = _state.copyWith(email: v);
    notifyListeners();
  }

  void updatePassword(String v) {
    _state = _state.copyWith(password: v);
    notifyListeners();
  }

  Future<void> login() async {
    if (!_state.canSubmit) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.post(
        ApiEndpoints.login,
        body: {
          'email': _state.email,
          'password': _state.password,
        },
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body);

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
