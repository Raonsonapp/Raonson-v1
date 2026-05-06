import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'core/services/user_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Yandex Ads SDK
  MobileAds.initialize();

  // ✅ App configuration
  AppConfig.initialize(
    baseUrl: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://raonson-v1-go.onrender.com',
    ),
    appName: 'Raonson',
    enableLogs: true,
  );

  // ✅ Load cached user data
  await UserSession.loadCachedData();

  // ✅ Run app
  runApp(const RaonsonApp());
}
