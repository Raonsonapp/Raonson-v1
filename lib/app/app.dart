import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'app_config.dart';
import '../auth/login/login_screen.dart';
import '../navigation/bottom_nav/bottom_nav_scaffold.dart';

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: Builder(
        builder: (context) {
          final state = context.watch<AppState>();
          final controller = AppController(state);

          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            home: !state.isInitialized
                ? const Scaffold(
                    backgroundColor: AppColors.bg,
                    body: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.neonBlue,
                      ),
                    ),
                  )
                : (state.isAuthenticated
                    ? const BottomNavScaffold()
                    : const LoginScreen()),
            onGenerateRoute: controller.onGenerateRoute,
          );
        },
      ),
    );
  }
}
