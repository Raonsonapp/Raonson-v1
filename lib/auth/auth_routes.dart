import 'package:flutter/material.dart';

import 'login/login_screen.dart';
import 'register/register_screen.dart';
import 'password/forgot_password_screen.dart';
import 'password/reset_password_screen.dart';

class AuthRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/login': (_) => const LoginScreen(),
    '/register': (_) => const RegisterScreen(),
    '/auth/forgot-password': (_) => const ForgotPasswordScreen(),
  };

  static Route<dynamic>? onGenerate(RouteSettings settings) {
    if (settings.name == '/auth/reset-password') {
      final email = settings.arguments as String;
      return MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(email: email),
      );
    }
    return null;
  }
}
