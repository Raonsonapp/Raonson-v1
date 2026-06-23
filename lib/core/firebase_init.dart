// lib/core/firebase_init.dart
// Firebase + FCM push. Backend аллакай /notifications/push-token ва sendFCM
// дорад — мо танҳо token-ро мефиристем ва паёмҳои background-ро мегирем.
//
// Эзоҳ: намоиши banner дар ҳолати foreground ба flutter_local_notifications
// ниёз дорад (он Android core-library desugaring мехоҳад) — он алоҳида,
// баъди тафтиши build илова мешавад, то build-и ҷорӣ вайрон нашавад.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api/api_client.dart';

// Background/terminated — система худаш огоҳиро нишон медиҳад.
@pragma('vm:entry-point')
Future<void> _fcmBgHandler(RemoteMessage message) async {}

class FirebaseInit {
  static Future<void> init() async {
    await Firebase.initializeApp();
    await _initFCM();
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
    } catch (_) {
      // Push танзим нашуд — барнома бе он кор мекунад.
    }
  }
}
