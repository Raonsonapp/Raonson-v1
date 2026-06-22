// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'app_settings.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'app_config.dart';
import 'app_splash.dart';
import '../auth/login/login_screen.dart';
import '../navigation/bottom_nav/bottom_nav_scaffold.dart';
import '../core/analytics/analytics_observer.dart';

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  static final AnalyticsObserver _analyticsObserver = AnalyticsObserver();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: Builder(
        builder: (context) {
          final state      = context.watch<AppState>();
          final controller = AppController(state);

          // ✅ MaterialApp listens to AppSettingsState → theme & language
          //    changes apply INSTANTLY across the whole app (realtime).
          return AnimatedBuilder(
            animation: AppSettingsState.instance,
            builder: (context, _) {
              final settings = AppSettingsState.instance;
              return MaterialApp(
                title: AppConfig.appName,
                debugShowCheckedModeBanner: false,
                theme:      AppTheme.light(),
                darkTheme:  AppTheme.dark(),
                themeMode:  settings.theme,
                // ✅ Splash — blank spinner ўрнига чиройли loading
                home: !state.isInitialized
                    ? const AppSplash()
                    : (state.isAuthenticated
                        ? const BottomNavScaffold()
                        : const LoginScreen()),
                onGenerateRoute: controller.onGenerateRoute,
                navigatorObservers: [_analyticsObserver],
              );
            },
          );
        },
      ),
    );
  }
}
