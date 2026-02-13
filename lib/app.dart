import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raonson',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routes: AppRoutes.routes,
      initialRoute: AppRoutes.login,
    );
  }
}
