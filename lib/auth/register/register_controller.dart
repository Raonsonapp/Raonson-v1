import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import 'register_state.dart';

class RegisterController extends ChangeNotifier {
  RegisterState _state = const RegisterState();

  RegisterState get state => _state;

  void updateUsername(String value) {
    _state = _state.copyWith(username: value, error: null);
    notifyListeners();
  }

  void updatePassword(String value) {
    _state = _state.copyWith(password: value, error: null);
    notifyListeners();
  }

  void updateConfirmPassword(String value) {
    _state = _state.copyWith(confirmPassword: value, error: null);
    notifyListeners();
  }

  Future<void> register(BuildContext context) async {
    if (!_state.canSubmit) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        '/auth/register',
        body: {
          'username': _state.username,
          'password': _state.password,
        },
      );

      final token = response['token'] as String;

      await TokenStorage.instance.saveToken(token);

      AnalyticsService.instance.logEvent(
        AnalyticsEvents.register,
        params: {'username': _state.username},
      );

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _state = _state.copyWith(
        error: 'Registration failed. Try another username.',
      );
      notifyListeners();
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }
}
