// lib/core/firebase_init.dart
// Firebase + FCM push. Backend аллакай /notifications/push-token ва sendFCM
// дорад — мо token-ро мефиристем, паёмҳои background-ро система нишон медиҳад,
// ва дар foreground худамон бо flutter_local_notifications banner нишон медиҳем.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api/api_client.dart';

// Background/terminated — система худаш огоҳиро нишон медиҳад.
@pragma('vm:entry-point')
Future<void> _fcmBgHandler(RemoteMessage message) async {}

class FirebaseInit {
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Channel-и огоҳиҳо (Android 8+ талаб мекунад).
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'raonson', 'Raonson',
    description: 'Огоҳиҳои Raonson',
    importance: Importance.high,
  );

  static Future<void> init() async {
    // Ҳама дар try — агар Firebase танзим нашуда бошад (google-services.json
    // нест), барнома ҳаргиз crash намекунад, танҳо push кор намекунад.
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
      );
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (_) {}
  }

  static Future<void> _initFCM() async {
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_fcmBgHandler);

      // Token-ро ба backend мефиристем (push_tokens table).
      final token = await fm.getToken();
      if (token != null && token.isNotEmpty) {
        ApiClient.instance.post('/notifications/push-token',
            body: {'token': token, 'platform': 'fcm'});
      }
      // Token нав шуд → дубора фирист.
      fm.onTokenRefresh.listen((t) {
        ApiClient.instance.post('/notifications/push-token',
            body: {'token': t, 'platform': 'fcm'});
      });

      // Foreground — система banner нишон намедиҳад, мо худамон нишон медиҳем.
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null) return;
        _localNotif.show(
          msg.hashCode, n.title, n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id, _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      });
    } catch (_) {
      // Push танзим нашуд — барнома бе он кор мекунад.
    }
  }
}
