import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/app_routes.dart';

/// Route guards for Raonson
/// Controls access based on authentication state
class RouteGuards {
  /// Redirect logic for protected routes
  static Route<dynamic>? onGenerateRouteGuarded(
    RouteSettings settings,
    AppState appState,
  ) {
    final routeName = settings.name ?? '';

    // ================= PUBLIC ROUTES =================
    if (_isPublicRoute(routeName)) {
      return null; // allow
    }

    // ================= AUTH REQUIRED =================
    if (!appState.isAuthenticated) {
      return _redirectToLogin();
    }

    return null; // allow
  }

  // --------------------------------------------------

  static bool _isPublicRoute(String route) {
    return route == AppRoutes.login ||
        route == AppRoutes.register ||
        route == AppRoutes.emailVerify ||
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
