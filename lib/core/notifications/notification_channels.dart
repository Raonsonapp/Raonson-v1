// lib/core/notifications/notification_channels.dart
// ════════════════════════════════════════════════════════════════════
//  Каналҳои огоҳиномаи Android.
//
//  Аз Android 8 ҳар огоҳинома бояд канал дошта бошад. Канал он аст,
//  ки корбар дар танзимоти СИСТЕМА идора мекунад: садо, ларзиш,
//  экрани қулф.
//
//  Каналҳо КАМ нигоҳ дошта мешаванд. Даҳҳо канал корбарро дар
//  танзимоти система гум мекунад ва ӯ ҳамаро якбора хомӯш мекунад.
//
//  Шиносаҳо бо сервер (backend/notify/kind.go) мувофиқанд — сервер
//  channel_id-ро дар payload мефиристад.
//
//  ⚠️ Садои канал баъди сохта шудан ДИГАР ТАҒЙИР НАМЕЁБАД (қоидаи
//  Android). Барои ҳамин каналҳои бо садои нав шиносаи нав (_v2)
//  доранд, ва каналҳои кӯҳна нест карда мешаванд — вагарна дар
//  телефонҳои аллакай насбшуда садои кӯҳна мемонд.
// ════════════════════════════════════════════════════════════════════
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../calls/call_strings.dart';
import '../i18n/strings.dart';

class NotificationChannels {
  NotificationChannels._();

  /// Паём — «поп»-и кӯтоҳ (мисли Instagram Direct).
  static const messages = 'messages_v2';

  /// Лайк, шарҳ, обуна, зикр — оҳанги нарми дуоҳанга.
  static const social = 'social_v2';

  /// Зангҳо — оҳанги занг. Экрани пурраи зангро flutter_callkit_incoming
  /// мекашад; ин канал барои «занги аздастрафта» ва iOS аст.
  static const calls = 'calls_v2';

  /// Ҷамъбаст, нишон, зинаи эҷодкор.
  static const creator = 'creator';

  /// Тавсия ва тренд — оромтарин.
  static const discovery = 'discovery';

  /// Кампания ва пардохт.
  static const marketplace = 'marketplace';

  /// Канали захиравӣ барои payload-и бе channel_id.
  static const fallback = social;

  /// Каналҳои кӯҳна, ки нест карда мешаванд (дар танзимоти система
  /// такрор нашаванд).
  static const legacy = ['messages', 'social'];

  // Номи файлҳо дар android/app/src/main/res/raw (бе васеъшавӣ).
  static const soundMessage = 'raonson_message';
  static const soundSocial = 'raonson_social';
  static const soundRingtone = 'raonson_ringtone';

  /// Ҳамаи каналҳоро дар система месозад.
  ///
  /// Ном ва тавсиф ТАРҶУМА мешаванд: корбар онҳоро дар танзимоти
  /// Android мебинад, на дар барнома.
  static List<AndroidNotificationChannel> all() => [
        AndroidNotificationChannel(
          messages,
          tr('nch.messages'),
          description: tr('nch.messagesDesc'),
          importance: Importance.high,
          sound: const RawResourceAndroidNotificationSound(soundMessage),
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          social,
          tr('nch.social'),
          description: tr('nch.socialDesc'),
          importance: Importance.defaultImportance,
          sound: const RawResourceAndroidNotificationSound(soundSocial),
          playSound: true,
        ),
        AndroidNotificationChannel(
          calls,
          CallStrings.t('channel'),
          description: CallStrings.t('channelDesc'),
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound(soundRingtone),
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 600, 800]),
        ),
        AndroidNotificationChannel(
          creator,
          tr('nch.creator'),
          description: tr('nch.creatorDesc'),
          importance: Importance.low,
        ),
        AndroidNotificationChannel(
          discovery,
          tr('nch.discovery'),
          description: tr('nch.discoveryDesc'),
          // Паст: тавсия набояд экранро банд кунад.
          importance: Importance.low,
        ),
        AndroidNotificationChannel(
          marketplace,
          tr('nch.marketplace'),
          description: tr('nch.marketplaceDesc'),
          importance: Importance.high,
        ),
      ];

  /// Аҳамияти канал — барои огоҳиномаи маҳаллӣ дар foreground.
  static Importance importanceOf(String channelId) {
    switch (channelId) {
      case calls:
        return Importance.max;
      case messages:
      case marketplace:
        return Importance.high;
      case creator:
      case discovery:
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  /// Садои канал — огоҳиномаи маҳаллӣ бояд ҳамон садоро дошта бошад
  /// (дар Android < 8 канал нест ва садо аз худи огоҳинома гирифта мешавад).
  static AndroidNotificationSound? soundOf(String channelId) {
    switch (channelId) {
      case messages:
        return const RawResourceAndroidNotificationSound(soundMessage);
      case social:
        return const RawResourceAndroidNotificationSound(soundSocial);
      case calls:
        return const RawResourceAndroidNotificationSound(soundRingtone);
      default:
        return null;
    }
  }

  /// Канали шинохта ё захиравӣ.
  ///
  /// Канали номаълум дар Android огоҳиномаро НОБУД мекунад — бе
  /// ягон хато. Барои ҳамин ҳар қимати бегона ба канали иҷтимоӣ
  /// меафтад. Шиносаҳои кӯҳна (сервери кӯҳна) ба навашон мераванд.
  static String resolve(String? channelId) {
    switch (channelId) {
      case messages:
      case social:
      case calls:
      case creator:
      case discovery:
      case marketplace:
        return channelId!;
      case 'messages':
        return messages;
      case 'social':
        return social;
      default:
        return fallback;
    }
  }
}
