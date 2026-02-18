import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/app_routes.dart';

class RouteGuards {
  static Route<dynamic>? onGenerateRouteGuarded(
    RouteSettings settings,
    AppState appState,
  ) {
    final routeName = settings.name ?? '';

    if (_isPublicRoute(routeName)) {
      return null;
    }

    if (!appState.isAuthenticated) {
      return _redirectToLogin();
    }

    return null;
  }

  static bool _isPublicRoute(String route) {
    return route == AppRoutes.login ||
        route == AppRoutes.register ||
        route == AppRoutes.otpVerify ||
        route == AppRoutes.forgotPassword ||
        route == AppRoutes.resetPassword;
  }

  static Route _redirectToLogin() {
    return MaterialPageRoute(
      settings: const RouteSettings(name: AppRoutes.login),
      builder: (_) => const SizedBox.shrink(),
    );
  }
}
