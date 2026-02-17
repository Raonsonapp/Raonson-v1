// lib/app/app_routes.dart
import 'package:flutter/material.dart';

// Auth
import '../auth/login/login_screen.dart';
import '../auth/register/register_screen.dart';

// Core
import '../navigation/bottom_nav/bottom_nav_bar.dart';

/// Centralized route definitions for Raonson.
/// FINAL & LOCKED.
class AppRoutes {
  // ===== Route Names =====
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  // ===== Route Table =====
  static Map<String, WidgetBuilder> routes = {
    splash: (_) => const _SplashPlaceholder(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    home: (_) => const BottomNavBar(),
  };

  // ===== Helpers =====
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text(
            'Route not found: ${settings.name}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  const AppRoutes._();
}

/// Temporary splash placeholder.
/// Replaced later by real splash feature.
class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
