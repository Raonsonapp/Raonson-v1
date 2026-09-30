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
//
//  Занг (type=incoming_call) data-only меояд ва огоҳинома НЕСТ: он ба
//  экрани пурраи занг меравад (lib/calls), на ба banner.
// ════════════════════════════════════════════════════════════════════
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../calls/call_coordinator.dart';
import '../calls/call_payload.dart';
import '../calls/callkit_bridge.dart';
import '../chat/chat_repository.dart';
import '../chat/room/chat_room_screen.dart';
import '../models/message_model.dart';
import 'api/api_client.dart';
import 'links/deep_links.dart';
import 'notifications/active_chat.dart';
import 'notifications/notification_channels.dart';
import 'notifications/upload_notifier.dart';

// Background/terminated.
//
// Огоҳиномаи оддиро система худаш нишон медиҳад. Занг data-only аст —
// ин ҷо экрани пурраи натиҳӣ (қабул/рад + оҳанг) кашида мешавад, ҳатто
// вақте барнома пӯшида ё телефон қулф аст.
@pragma('vm:entry-point')
Future<void> _fcmBgHandler(RemoteMessage message) async {
  final call = IncomingCall.fromPush(message.data);
  if (call == null) return;
  await showCallFromBackgroundPush(call);
}

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
    // Зангҳо ба Firebase вобаста нестанд: сокет ва экрани натиҳӣ бе
    // google-services.json ҳам кор мекунанд.
    CallCoordinator.instance.init(navigator);
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
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
        // Пахши banner-и маҳаллӣ низ бояд ба ҳамон ҷо барад.
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null && payload.isNotEmpty) _openPayload(payload);
        },
      );
      LocalUploadNotificationSink.markInitialized();
      final android = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      for (final ch in NotificationChannels.all()) {
        await android?.createNotificationChannel(ch);
      }
      await android
          ?.createNotificationChannel(NotificationChannels.uploadsChannel());
      // Каналҳои кӯҳна (садои пешина) — то дар танзимоти система ду
      // «Паёмҳо» набошад.
      for (final id in NotificationChannels.legacy) {
        await android?.deleteNotificationChannel(id);
      }
    } catch (_) {}
  }

  static Future<void> _initFCM() async {
    final fm = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_fcmBgHandler);

    // Шунавандаҳо АВВАЛ сабт мешаванд: getToken() бе интернет хато
    // мепартояд ва пеш аз ин тамоми коркарди push дар сессия гум мешуд.

    // Foreground — система banner нишон намедиҳад, мо худамон.
    FirebaseMessaging.onMessage.listen(_showLocal);

    // Барнома дар паснамо буд ва корбар огоҳиномаро пахш кард.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openData(m.data));

    // Барнома ПӮШИДА буд: огоҳинома онро кушод.
    try {
      final initial = await fm.getInitialMessage();
      if (initial != null) {
        // Каме таъхир, то Navigator тайёр шавад.
        Future.delayed(const Duration(milliseconds: 400),
            () => _openData(initial.data));
      }
    } catch (_) {}

    fm.onTokenRefresh.listen(_sendToken);
    // Токен охир ва ҷудо: хатои шабака набояд чизи дигарро боздорад.
    try {
      await _sendToken(await fm.getToken());
    } catch (_) {
      // Ҳангоми onTokenRefresh ё оғози оянда дубора фиристода мешавад.
    }
  }

  // Префикси payload-и banner барои паёми бе линк (танҳо chatId).
  static const _chatPayload = 'chat:';

  /// Payload-и огоҳиномаро ба линк ё чат табдил медиҳад.
  ///
  /// Паёмҳои чат аксар вақт 'link' надоранд — танҳо type=message ва
  /// id (chatId). Бе ин пахш ба ҳеҷ ҷо намебурд.
  static String _payloadOf(Map<String, dynamic> data) {
    final link = data['link']?.toString() ?? '';
    if (link.isNotEmpty) return link;
    final id = data['id']?.toString() ?? '';
    if (data['type']?.toString() == 'message' && id.isNotEmpty) {
      return '$_chatPayload$id';
    }
    return '';
  }

  static void _openData(Map<String, dynamic> data) =>
      _openPayload(_payloadOf(data));

  /// Navigator ҳангоми cold start метавонад ҳанӯз сохта нашуда бошад —
  /// якчанд бор бо таъхир кӯшиш мекунем, на ки огоҳиномаро партоем.
  static void _openPayload(String payload, [int attempt = 0]) {
    if (payload.isEmpty) return;
    if (navigatorKey?.currentState == null) {
      if (attempt < 5) {
        Future.delayed(const Duration(milliseconds: 500),
            () => _openPayload(payload, attempt + 1));
      }
      return;
    }
    if (payload.startsWith(_chatPayload)) {
      _openChat(payload.substring(_chatPayload.length));
    } else {
      _openLink(payload);
    }
  }

  /// Чатро аз рӯи chatId мекушояд.
  ///
  /// ChatRoomScreen ҳамсӯҳбатро мехоҳад, на chatId — ӯро аз inbox
  /// меёбем. Агар ёфт нашавад, рӯйхати чатҳо кушода мешавад.
  static Future<void> _openChat(String chatId) async {
    MessageModel? hit;
    try {
      final chats = await ChatRepository().getInboxChats();
      for (final c in chats) {
        if (c.chatId == chatId) { hit = c; break; }
      }
    } catch (_) {}
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    if (hit != null) {
      final peer = hit.peer;
      nav.push(MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: peer)));
    } else {
      nav.pushNamed('/messages');
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
    // Занг — экрани пурра, на banner (сокет ҳам метавонад онро аллакай
    // нишон дода бошад — CallCoordinator такрорро мепартояд).
    final call = IncomingCall.fromPush(msg.data);
    if (call != null) {
      CallCoordinator.instance.onPushIncoming(call);
      return;
    }
    final n = msg.notification;
    if (n == null) return;
    // Паём ба чате, ки ҲОЗИР кушода аст — на banner, на садо: одам онро
    // аллакай мебинад (мисли Instagram/WhatsApp).
    if (msg.data['type']?.toString() == 'message' &&
        ActiveChat.isOpen(navigatorKey, msg.data['id']?.toString() ?? '')) {
      return;
    }
    final channel = NotificationChannels.resolve(
        msg.notification?.android?.channelId ??
            msg.data['channelId']?.toString());
    final link = _payloadOf(msg.data);

    // Паёмҳои як чат як огоҳинома мешаванд (охирин), на рӯйхати дароз.
    final chatId = msg.data['type']?.toString() == 'message'
        ? (msg.data['id']?.toString() ?? '')
        : '';
    _localNotif.show(
      chatId.isNotEmpty ? chatId.hashCode : msg.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel,
          importance: NotificationChannels.importanceOf(channel),
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: const Color(0xFF2F6BFF),
          // Android < 8 канал надорад — садо аз худи огоҳинома.
          sound: NotificationChannels.soundOf(channel),
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
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

    // Роҳҳои дохилӣ, ки линки умумӣ нестанд.
    //
    // ⚠️ Даъвати ҳамкорӣ пеш ба худи ПОСТ мебурд. Вале одам ҳанӯз
    // ҳамкор нест: ӯ постро мебинад ва ҳеҷ тугмаи қабул намебинад —
    // даъват «кор намекунад».
    if (link == '/collab-invites') {
      nav.pushNamed(link);
      return;
    }

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
      if (granted) {
        await _sendToken(await fm.getToken());
        // Android 14+: бе ин занг дар экрани қулф танҳо banner мешавад.
        await CallCoordinator.instance.maybeAskFullScreenPermission();
      }
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
  /// Токени ин дастгоҳро аз НАВ ба аккаунти ФАЪОЛ мебандад.
  ///
  /// ⚠️ Баъди гузариш ба аккаунти дигар ин ҲАТМист.
  ///
  /// Токени FCM ба ДАСТГОҲ тааллуқ дорад, на ба аккаунт. Дар сервер
  /// он ба як корбар баста мешавад. Агар баъди гузариш аз нав
  /// фиристода нашавад, он ба аккаунти КӮҲНА баста мемонад — яъне
  /// огоҳиномаҳои аккаунти нав намеоянд, ва огоҳиномаҳои аккаунти
  /// кӯҳна ба ҳамин телефон меоянд.
  static Future<void> rebindToken() async {
    try {
      await _sendToken(await FirebaseMessaging.instance.getToken());
    } catch (e) {
      debugPrint('[FCM] rebind: $e');
    }
  }

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
