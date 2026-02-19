import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/* =========================
   REGISTER STATE
========================= */
@immutable
class RegisterState {
  final String username;
  final String email;
  final String password;
  final String confirmPassword;
  final bool isLoading;
  final String? error;

  const RegisterState({
    this.username = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isLoading = false,
    this.error,
  });

  bool get canSubmit =>
      username.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      password.length >= 6 &&
      password == confirmPassword;

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

/* =========================
   REGISTER CONTROLLER
========================= */
class RegisterController extends ChangeNotifier {
  RegisterState _state = const RegisterState();
  RegisterState get state => _state;

  // 🔧 CHANGE THIS IF NEEDED
  static const String _baseUrl = 'https://raonson-v1.onrender.com';
  static const String _registerPath = '/auth/register';

  // ================= FIELD UPDATES =================

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

  // ================= REGISTER =================
  Future<bool> register() async {
    if (!_state.canSubmit) return false;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_registerPath'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': _state.username.trim(),
          'email': _state.email.trim(),
          'password': _state.password,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        dynamic body;
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          body = null;
        }

        throw Exception(
          body is Map<String, dynamic>
              ? (body['message'] ?? 'Registration failed')
              : 'Registration failed',
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
