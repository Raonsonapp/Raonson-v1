import 'dart:convert';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class LoginState {
  final String email;
  final String password;
  final bool isLoading;
  final String? error;

  LoginState({
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.error,
  });

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
  LoginState _state = LoginState();
  LoginState get state => _state;

  void updateEmail(String v) {
    _state = _state.copyWith(email: v);
    notifyListeners();
  }

  void updatePassword(String v) {
    _state = _state.copyWith(password: v);
    notifyListeners();
  }

  /// ✅ FINAL LOGIN (Instagram-style)
  Future<bool> login() async {
    if (!_state.canSubmit) return false;

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

      if (response.statusCode != 200) {
        dynamic body;
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          body = null;
        }

        throw Exception(
          body is Map<String, dynamic>
              ? (body['message'] ?? 'Login failed')
              : 'Login failed',
        );
      }

      // ✅ SUCCESS
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
      notifyListeners();
      return false;
    }
  }
}
