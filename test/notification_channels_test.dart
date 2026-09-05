// test/notification_channels_test.dart
// Каналҳои огоҳинома.
//
// Хатари асосӣ хомӯш аст: Android огоҳиномаро бо канали НОМАЪЛУМ
// бе ягон хато мепартояд. Корбар ҳеҷ чиз намебинад ва сабабаш
// маълум намешавад.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/notifications/notification_channels.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  group('ҳалли канал', () {
    test('канали шинохта ҳамон тавр мемонад', () {
      for (final id in [
        NotificationChannels.messages,
        NotificationChannels.social,
        NotificationChannels.creator,
        NotificationChannels.discovery,
        NotificationChannels.marketplace,
      ]) {
        expect(NotificationChannels.resolve(id), id);
      }
    });

    test('канали номаълум ба канали захиравӣ меафтад', () {
      for (final bad in [null, '', 'raonson', 'unknown', 'MESSAGES']) {
        expect(NotificationChannels.resolve(bad),
            NotificationChannels.fallback,
            reason: 'қимати $bad');
      }
    });

    test('канали захиравӣ худаш шинохта аст', () {
      expect(NotificationChannels.resolve(NotificationChannels.fallback),
          NotificationChannels.fallback);
    });
  });

  group('аҳамияти канал', () {
    test('паём баландтарин аҳамият дорад', () {
      expect(NotificationChannels.importanceOf(NotificationChannels.messages),
          Importance.high);
    });

    test('тавсия набояд экранро банд кунад', () {
      expect(NotificationChannels.importanceOf(NotificationChannels.discovery),
          Importance.low);
      expect(NotificationChannels.importanceOf(NotificationChannels.creator),
          Importance.low);
    });

    test('канали номаълум аҳамияти миёна мегирад', () {
      expect(NotificationChannels.importanceOf('unknown'),
          Importance.defaultImportance);
    });
  });

  group('сохтани каналҳо', () {
    test('каналҳо кам ва бе такрор мебошанд', () {
      final all = NotificationChannels.all();
      // Даҳҳо канал корбарро дар танзимоти система гум мекунад.
      expect(all.length, lessThanOrEqualTo(6));
      final ids = all.map((c) => c.id).toSet();
      expect(ids.length, all.length, reason: 'шиносаи такрорӣ');
    });

    test('ҳар канал ном ва тавсифи тарҷумашуда дорад', () {
      for (final c in NotificationChannels.all()) {
        expect(c.name, isNotEmpty, reason: c.id);
        expect(c.name, isNot(startsWith('nch.')),
            reason: '${c.id}: тарҷума нест');
        expect(c.description, isNotNull);
        expect(c.description!, isNot(startsWith('nch.')),
            reason: '${c.id}: тавсиф тарҷума нашуд');
      }
    });

    test('ҳар се забон номи худро медиҳад', () async {
      final seen = <String>{};
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        seen.add(NotificationChannels.all().first.name);
      }
      expect(seen.length, 3, reason: 'забонҳо номи якхела доранд');
    });

    test('калидҳои матн дар ҳар се забон ҳастанд', () async {
      const keys = [
        'nch.messages', 'nch.messagesDesc',
        'nch.social', 'nch.socialDesc',
        'nch.creator', 'nch.creatorDesc',
        'nch.discovery', 'nch.discoveryDesc',
        'nch.marketplace', 'nch.marketplaceDesc',
        'nperm.title', 'nperm.body', 'nperm.enable', 'nperm.later',
      ];
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in keys) {
          expect(tr(k), isNot(k), reason: '$lang: $k тарҷума надорад');
        }
      }
    });
  });
}
