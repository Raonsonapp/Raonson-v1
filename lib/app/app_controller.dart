import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_routes.dart';

// ✅ ИМПОРТИ ЭКРАНИ ВОҚЕӢ
import '../auth/login/login_screen.dart';

class AppController {
  final AppState appState;

  AppController(this.appState);

  String get initialRoute {
    if (!appState.isInitialized) return AppRoutes.splash;
    return appState.isAuthenticated
        ? AppRoutes.home
        : AppRoutes.login;
  }

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return _page(const LoginScreen());

      case AppRoutes.register:
        return _page(const Placeholder());

      case AppRoutes.home:
        return _page(const Placeholder());

      case AppRoutes.profile:
        return _page(const Placeholder());

      case AppRoutes.create:
        return _page(const Placeholder());

      case AppRoutes.chat:
        return _page(const Placeholder());

      case AppRoutes.notifications:
        return _page(const Placeholder());

      default:
        return _page(const Placeholder());
    }
  }

  MaterialPageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
