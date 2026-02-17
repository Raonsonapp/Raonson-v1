import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'app_config.dart';

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..setInitialized(true),
      child: Builder(
        builder: (context) {
          final state = context.watch<AppState>();
          final controller = AppController(state);

          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            initialRoute: controller.initialRoute,
            onGenerateRoute: controller.onGenerateRoute,
          );
        },
      ),
    );
  }
}
