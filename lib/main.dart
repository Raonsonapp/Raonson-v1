// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'core/services/user_session.dart';
import 'core/services/network_service.dart';
import 'core/services/server_wakeup_service.dart';
import 'core/ads/ads_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ✅ 2. AppConfig — АВВАЛ
  AppConfig.initialize(
    baseUrl: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://raonson-v1-go.onrender.com',
    ),
    appName: 'Raonson',
    enableLogs: true,
  );

  // ✅ 3. Cache-ро ФАВРАН бор кун — бе интернет ҳам кор мекунад
  await UserSession.loadCachedData();

  // ✅ 4. Network monitoring
  NetworkService.instance.init();

  // ✅ 5. Серверро background-да бедор кун (Render.com free tier)
  ServerWakeupService.instance.wakeUp();
  ServerWakeupService.instance.startKeepAlive();

  // ✅ 6. Ads
  MobileAds.initialize();
  AdsManager.instance.init();

  // ✅ 7. App-ро кушо — ФАВРАН, бе интернет интизор шудан
  runApp(const RaonsonApp());
}
