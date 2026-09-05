// lib/core/firebase_init.dart
// ════════════════════════════════════════════════════════════════════
//  Firebase + FCM push.
//
//  Се ҳолати кушодани огоҳинома вуҷуд дорад ва ҳар се бояд ба ҲАМОН
//  ҷо барад:
//    • барнома кушода (foreground) — banner-и маҳаллӣ
//    • барнома дар паснамо — onMessageOpenedApp
//    • барнома пӯшида буд — getInitialMessage
//
//  Пештар ҳеҷ яке аз онҳо коркард намешуд: огоҳинома кушода мешуд,
//  вале барнома танҳо экрани асосиро нишон медод.
//
//  Routing-и дуюм сохта намешавад — ҳамон DeepLinks истифода мешавад.
// ════════════════════════════════════════════════════════════════════
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api/api_client.dart';
import 'links/deep_links.dart';
import 'notifications/notification_channels.dart';

// Background/terminated — система худаш огоҳиро нишон медиҳад.
@pragma('vm:entry-point')
Future<void> _fcmBgHandler(RemoteMessage message) async {}

class FirebaseInit {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Navigator барои кушодани мӯҳтаво аз огоҳинома.
  ///
  /// Бе он огоҳинома танҳо барномаро мекушояд ва одам худаш бояд
  /// мӯҳтаворо ҷустуҷӯ кунад.
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> init({GlobalKey<NavigatorState>? navigator}) async {
    navigatorKey = navigator;
    // Ҳама дар try — агар Firebase танзим нашуда бошад
    // (google-services.json нест), барнома ҳаргиз crash намекунад.
    try {
      await Firebase.initializeApp();
      await _initLocalNotif();
      await _initFCM();
    } catch (_) {
      // Firebase/FCM дастрас нест — барнома бе он кор мекунад.
    }
  }

  static Future<void> _initLocalNotif() async {
    try {
      await _localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        // Пахши banner-и маҳаллӣ низ бояд ба ҳамон ҷо барад.
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null && payload.isNotEmpty) _openLink(payload);
        },
      );
      final android = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      for (final ch in NotificationChannels.all()) {
        await android?.createNotificationChannel(ch);
      }
    } catch (_) {}
  }

  static Future<void> _initFCM() async {
    final fm = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_fcmBgHandler);

    await _sendToken(await fm.getToken());
    fm.onTokenRefresh.listen(_sendToken);

    // Foreground — система banner нишон намедиҳад, мо худамон.
    FirebaseMessaging.onMessage.listen(_showLocal);

    // Барнома дар паснамо буд ва корбар огоҳиномаро пахш кард.
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _openLink(m.data['link']?.toString() ?? '');
    });

    // Барнома ПӮШИДА буд: огоҳинома онро кушод.
    final initial = await fm.getInitialMessage();
    if (initial != null) {
      // Каме таъхир, то Navigator тайёр шавад.
      Future.delayed(const Duration(milliseconds: 400), () {
        _openLink(initial.data['link']?.toString() ?? '');
      });
    }
  }

  static Future<void> _sendToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await ApiClient.instance.post('/notifications/push-token', body: {
        'token': token,
        // Сервер платформаро барои шакли payload истифода мебарад.
        'platform': _platform(),
      });
    } catch (_) {
      // Токен ҳангоми оғози оянда дубора фиристода мешавад.
    }
  }

  // Танҳо ду қимат: сервер ҳар чизи дигарро android мешуморад.
  static String _platform() => Platform.isIOS ? 'ios' : 'android';

  /// Banner-и маҳаллӣ ҳангоми кушода будани барнома.
  ///
  /// Канал аз сервер меояд; канали номаълум огоҳиномаро дар Android
  /// хомӯшона нобуд мекунад, бинобар ин он тафтиш мешавад.
  static void _showLocal(RemoteMessage msg) {
    final n = msg.notification;
    if (n == null) return;
    final channel = NotificationChannels.resolve(
        msg.notification?.android?.channelId ??
            msg.data['channelId']?.toString());
    final link = msg.data['link']?.toString() ?? '';

    _localNotif.show(
      msg.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel,
          importance: NotificationChannels.importanceOf(channel),
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: link,
    );
  }

  /// Мӯҳтаворо аз линки огоҳинома мекушояд.
  ///
  /// Линки холӣ ё ношинос барномаро НАМЕПАРТОЯД: он танҳо ҳамон ҷое
  /// мемонад, ки ҳаст.
  static void _openLink(String link) {
    if (link.isEmpty) return;
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    if (!DeepLinks.parse(link).isValid) return;
    nav.pushNamed(link);
  }

  static bool _permissionRequested = false;

  /// Иҷозати огоҳиномаро мепурсад.
  ///
  /// Дар кадри аввал пурсида НАМЕШАВАД: экран бояд аввал фоидаро
  /// шарҳ диҳад (ниг. notification_permission_sheet.dart).
  ///
  /// Пас аз рад кардан такрор пурсида намешавад — Android/iOS ҳам
  /// такрорро иҷозат намедиҳанд ва такрор пурсидан безоркунанда аст.
  static Future<bool> requestNotificationPermission() async {
    if (_permissionRequested) return false;
    _permissionRequested = true;
    try {
      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission();
      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) await _sendToken(await fm.getToken());
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Ҳолати ҷории иҷозат.
  static Future<AuthorizationStatus> permissionStatus() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus;
    } catch (_) {
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Ҳангоми баромадан аз аккаунт токенро мебарад.
  ///
  /// Бе ин, огоҳиномаҳои корбари қаблӣ ба ҳамон телефон мерафтанд.
  static Future<void> clearToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      // delete() бадан қабул намекунад — токен дар query меравад.
      await ApiClient.instance
          .delete('/notifications/push-token?token=$token');
    } catch (_) {}
  }
}
