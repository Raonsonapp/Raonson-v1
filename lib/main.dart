// lib/main.dart
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'core/services/user_session.dart';
import 'core/services/network_service.dart'; // ← НАВ
import 'core/ads/ads_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Network monitoring — АВВАЛ init кун
  NetworkService.instance.init();

  // ✅ Ads init
  MobileAds.initialize();

  // ✅ App config
  AppConfig.initialize(
    baseUrl: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://raonson-v1-go.onrender.com',
    ),
    appName: 'Raonson',
    enableLogs: true,
  );

  // ✅ Cache-ро бор кун — фавран, бе интернет
  await UserSession.loadCachedData();

  // ✅ Ads preload
  AdsManager.instance.init();

  runApp(const RaonsonApp());
}
