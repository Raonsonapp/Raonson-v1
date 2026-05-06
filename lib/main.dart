import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'core/services/user_session.dart';
import 'core/ads/ads_manager.dart'; // ← NEW

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Yandex Ads SDK (MobileAds.initialize is also called
  //    inside AdsManager.init() — safe to call twice, SDK deduplicates)
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

  // ✅ Init AdsManager — preloads interstitial & rewarded in background
  AdsManager.instance.init();

  // ✅ Run app
  runApp(const RaonsonApp());
}
