import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_endpoints.dart';
import 'register_state.dart';

class RegisterController extends ChangeNotifier {
  RegisterState _state = const RegisterState();

  RegisterState get state => _state;

  // ================== UPDATE FIELDS ==================

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

  // ================== REGISTER ==================
  /// Instagram-style register
  /// ❌ Token интизор НЕ мешавем
  /// ✅ Танҳо success / error
  Future<bool> register() async {
    if (!_state.canSubmit) return false;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        body: {
          'username': _state.username.trim(),
          'email': _state.email.trim(),
          'password': _state.password,
        },
      );

      // ❌ Error from backend
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
