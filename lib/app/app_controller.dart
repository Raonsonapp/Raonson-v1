import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_routes.dart';

// AUTH SCREENS
import '../auth/login/login_screen.dart';
import '../auth/register/register_screen.dart';

class AppController {
  final AppState appState;

  AppController(this.appState);

  String get initialRoute {
    if (!appState.isInitialized) return AppRoutes.splash;

    return appState.isAuthenticated
        ? AppRoutes.home
        : AppRoutes.login;
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ================= AUTH =================
      case AppRoutes.login:
        return _page(const LoginScreen());

      case AppRoutes.register:
        return _page(const RegisterScreen());

      // ================= MAIN =================
      case AppRoutes.home:
        return _page(const Scaffold(
          body: Center(child: Text('Home')),
        ));

      case AppRoutes.reels:
        return _page(const Scaffold(
          body: Center(child: Text('Reels')),
        ));

      case AppRoutes.chat:
        return _page(const Scaffold(
          body: Center(child: Text('Chat')),
        ));

      case AppRoutes.search:
        return _page(const Scaffold(
          body: Center(child: Text('Search')),
        ));

      case AppRoutes.profile:
        return _page(const Scaffold(
          body: Center(child: Text('Profile')),
        ));

      // ================= ACTIONS =================
      case AppRoutes.create:
        return _page(const Scaffold(
          body: Center(child: Text('Create Post')),
        ));

      case AppRoutes.notifications:
        return _page(const Scaffold(
          body: Center(child: Text('Notifications')),
        ));

      default:
        return _page(const Scaffold(body: SizedBox()));
    }
  }

  MaterialPageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
