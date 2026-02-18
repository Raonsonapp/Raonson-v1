import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class RegisterState {
  final String username;
  final String email;
  final String password;
  final bool isLoading;
  final String? error;

  const RegisterState({
    required this.username,
    required this.email,
    required this.password,
    required this.isLoading,
    this.error,
  });

  factory RegisterState.initial() {
    return const RegisterState(
      username: '',
      email: '',
      password: '',
      isLoading: false,
    );
  }

  bool get canSubmit =>
      username.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty &&
      !isLoading;

  RegisterState copyWith({
    String? username,
    String? email,
    String? password,
    bool? isLoading,
    String? error,
  }) {
    return RegisterState(
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
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

  Future<void> register() async {
    if (!_state.canSubmit) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final res = await ApiClient.post(
        ApiEndpoints.register,
        body: {
          'username': _state.username,
          'email': _state.email,
          'password': _state.password,
        },
      );

      jsonDecode(res.body);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }
}
