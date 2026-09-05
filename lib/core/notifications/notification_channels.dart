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
// ════════════════════════════════════════════════════════════════════
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../i18n/strings.dart';

class NotificationChannels {
  NotificationChannels._();

  /// Паём — ягона канале, ки аҳамияти баландтарин дорад.
  static const messages = 'messages';

  /// Лайк, шарҳ, обуна, зикр.
  static const social = 'social';

  /// Ҷамъбаст, нишон, зинаи эҷодкор.
  static const creator = 'creator';

  /// Тавсия ва тренд — оромтарин.
  static const discovery = 'discovery';

  /// Кампания ва пардохт.
  static const marketplace = 'marketplace';

  /// Канали захиравӣ барои payload-и бе channel_id.
  static const fallback = 'social';

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
        ),
        AndroidNotificationChannel(
          social,
          tr('nch.social'),
          description: tr('nch.socialDesc'),
          importance: Importance.defaultImportance,
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

  /// Канали шинохта ё захиравӣ.
  ///
  /// Канали номаълум дар Android огоҳиномаро НОБУД мекунад — бе
  /// ягон хато. Барои ҳамин ҳар қимати бегона ба канали иҷтимоӣ
  /// меафтад.
  static String resolve(String? channelId) {
    switch (channelId) {
      case messages:
      case social:
      case creator:
      case discovery:
      case marketplace:
        return channelId!;
      default:
        return fallback;
    }
  }
}
