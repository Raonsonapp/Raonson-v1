// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/app_settings.dart';
import 'core/services/user_session.dart';
import 'core/services/account_manager.dart';
import 'core/services/subscription_service.dart';
import 'core/services/chat_lock_service.dart';
import 'core/services/network_service.dart';
import 'core/services/network_quality.dart';
import 'core/ads/ads_manager.dart';
import 'core/firebase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ✅ 1b. Image cache limits — бе ин, кэш бе ҳад меафзояд
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // ✅ 2. AppConfig — АВВАЛ
  AppConfig.initialize(
    baseUrl: const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'https://mahmadmurodov-raonson.hf.space',
    ),
    appName: 'Raonson',
    enableLogs: kDebugMode,
  );

  // ✅ 3. Cache-ро ПАРАЛЛЕЛ бор кун — тезтар аст
  await Future.wait([
    UserSession.loadCachedData(),
    AccountManager.load(),
    SubscriptionService.instance.load(),
    ChatLockService.instance.load(),
    NetworkQuality.init(),
    AppSettingsState.instance.init(),
  ]);

  // ✅ 4. Network monitoring
  NetworkService.instance.init();

  // ✅ 6. Ads
  MobileAds.initialize();
  AdsManager.instance.init();

  // ✅ 6.1 Firebase + FCM push (бехатар: агар танзим набошад, crash намешавад)
  FirebaseInit.init();

  // ✅ 7. App-ро кушо — ФАВРАН, бе интернет интизор шудан
  runApp(const RaonsonApp());
}
