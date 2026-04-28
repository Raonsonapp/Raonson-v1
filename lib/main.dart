import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/app_config.dart';
import 'core/services/user_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize(
    baseUrl: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://raonson-v1-go.onrender.com',
    ),
    appName: 'Raonson',
    enableLogs: true,
  );

  // Аватари кэшшударо аз SharedPreferences бор кун
  // то интернет набошад ҳам аватар нишон дода шавад
  await UserSession.loadCachedData();

  runApp(const RaonsonApp());
}
