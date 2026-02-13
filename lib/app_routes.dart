import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'bottom_nav/bottom_nav.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const app = '/app';

  static final routes = <String, WidgetBuilder>{
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    app: (_) => const BottomNav(),
  };
}
