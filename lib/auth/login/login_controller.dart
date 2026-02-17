import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import 'login_state.dart';

class LoginController extends ChangeNotifier {
  LoginState _state = const LoginState();

  LoginState get state => _state;

  void updateUsername(String value) {
    _state = _state.copyWith(username: value, error: null);
    notifyListeners();
  }

  void updatePassword(String value) {
    _state = _state.copyWith(password: value, error: null);
    notifyListeners();
  }

  Future<void> login(BuildContext context) async {
    if (!_state.canSubmit) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        '/auth/login',
        body: {
          'username': _state.username,
          'password': _state.password,
        },
      );

      final token = response['token'] as String;

      await TokenStorage.instance.saveToken(token);

      AnalyticsService.instance.logEvent(
        AnalyticsEvents.login,
        params: {'username': _state.username},
      );

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _state = _state.copyWith(
        error: 'Login failed. Check credentials.',
      );
      notifyListeners();
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }
}
