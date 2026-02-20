import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global app configuration (env, baseUrl, flags)
  await AppConfig.initialize(
    baseUrl: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://raonson-v1.onrender.com',
    ),
    appName: 'Raonson',
    enableLogs: true,
  );

  runApp(const RaonsonApp());
}
