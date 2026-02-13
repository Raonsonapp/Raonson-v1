import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'bottom_nav/bottom_nav.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';

  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const BottomNav());
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
