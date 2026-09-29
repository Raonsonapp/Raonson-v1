// test/calls_test.dart
// Занги воридотӣ: шакли push, такрор ва садоҳои каналҳо.
//
// Хатари асосӣ ХОМӮШ аст: номи майдони push иваз шавад — занг
// ҳеҷ гоҳ намезанад; дедупликатсия хато кунад — занги радшуда аз нав
// садо медиҳад. Ҳарду бе дастгоҳ санҷида мешаванд.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/calls/call_dedupe.dart';
import 'package:raonson/calls/call_payload.dart';
import 'package:raonson/calls/call_strings.dart';
import 'package:raonson/core/notifications/active_chat.dart';
import 'package:raonson/core/notifications/notification_channels.dart';

void main() {
  group('push-и занг (backend/notify/call.go → CallData)', () {
    const uuid = '0f8fad5b-d9cb-469f-a165-70867728950e';

    test('майдонҳои сервер хонда мешаванд', () {
      final c = IncomingCall.fromPush({
        'type': 'incoming_call',
        'callId': uuid,
        'callerId': 'u1',
        'callerName': 'ali',
        'callerAvatar': 'https://x/a.jpg',
        'callType': 'video',
        'sentAt': '1700000000000',
      })!;
      expect(c.callId, uuid);
      expect(c.callerId, 'u1');
      expect(c.callerName, 'ali');
      expect(c.callerAvatar, 'https://x/a.jpg');
      expect(c.isVideo, isTrue);
      expect(c.sentAtMs, 1700000000000);
    });

    test('push-и дигар занг нест', () {
      expect(IncomingCall.fromPush({'type': 'message', 'id': 'a_b'}), isNull);
      expect(IncomingCall.fromPush({}), isNull);
    });

    test('бе зангзананда — занг нест', () {
      expect(
          IncomingCall.fromPush({'type': 'incoming_call', 'callId': uuid}),
          isNull);
    });

    test('сервери кӯҳна (танҳо id) ҳам фаҳмида мешавад', () {
      final c = IncomingCall.fromPush({'type': 'incoming_call', 'id': 'u9'})!;
      expect(c.callerId, 'u9');
      expect(c.isVideo, isFalse);
    });

    test('callId-и ғайри-UUID ба UUID иваз мешавад (callkit танҳо UUID)', () {
      final c = IncomingCall.fromPush({
        'type': 'incoming_call',
        'callerId': 'u1',
        'callId': 'not-a-uuid',
        'sentAt': '5',
      })!;
      expect(IncomingCall.isUuid(c.callId), isTrue);
      // Муайян: ҳамон занг — ҳамон шиноса.
      final again = IncomingCall.fromPush({
        'type': 'incoming_call',
        'callerId': 'u1',
        'callId': 'not-a-uuid',
        'sentAt': '5',
      })!;
      expect(again.callId, c.callId);
    });

    test('намуди номаълум — аудио', () {
      for (final t in ['voice', 'audio', '', 'VIDEO?']) {
        final c = IncomingCall.fromPush(
            {'type': 'incoming_call', 'callerId': 'u', 'callType': t})!;
        expect(c.isVideo, isFalse, reason: t);
      }
      expect(
          IncomingCall.fromPush({
            'type': 'incoming_call',
            'callerId': 'u',
            'callType': 'Video'
          })!
              .isVideo,
          isTrue);
    });

    test('занги дер расида кӯҳна аст, вале сокет ҳеҷ гоҳ', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000100000);
      IncomingCall at(int ms) => IncomingCall(
          callId: uuid,
          callerId: 'u',
          callerName: '',
          callerAvatar: '',
          isVideo: false,
          sentAtMs: ms);
      expect(at(1700000100000 - 5000).isStale(now), isFalse);
      expect(at(1700000100000 - 120000).isStale(now), isTrue);
      expect(at(0).isStale(now), isFalse, reason: 'вақт номаълум');
    });

    test('extra-и callkit ҳамон зангро бармегардонад', () {
      final c = IncomingCall(
          callId: uuid,
          callerId: 'u1',
          callerName: 'ali',
          callerAvatar: 'a.jpg',
          isVideo: true,
          sentAtMs: 42);
      final back = IncomingCall.fromExtra(c.toExtra())!;
      expect(back.callId, uuid);
      expect(back.callerId, 'u1');
      expect(back.callerName, 'ali');
      expect(back.isVideo, isTrue);
      expect(back.sentAtMs, 42);
      expect(IncomingCall.fromExtra(null), isNull);
      expect(IncomingCall.fromExtra({'callerName': 'x'}), isNull);
    });

    test('ҳодисаи сокет', () {
      final c = IncomingCall.fromSocket({
        'from': 'u2',
        'fromUsername': 'vali',
        'fromAvatar': '',
        'callType': 'video',
      })!;
      expect(c.callerId, 'u2');
      expect(c.callerName, 'vali');
      expect(c.isVideo, isTrue);
      expect(IncomingCall.isUuid(c.callId), isTrue);
      expect(IncomingCall.fromSocket('bad'), isNull);
      expect(IncomingCall.fromSocket({'from': ''}), isNull);
    });
  });

  group('як занг — як экран', () {
    late DateTime now;
    late CallDedupe d;
    setUp(() {
      now = DateTime(2026, 1, 1, 12);
      d = CallDedupe(clock: () => now);
    });

    test('сокет, баъд push-и ҳамон занг — танҳо як бор', () {
      expect(d.shouldShow('u1', CallSource.socket), isTrue);
      expect(d.shouldShow('u1', CallSource.push), isFalse);
    });

    test('push, баъд сокет — танҳо як бор', () {
      expect(d.shouldShow('u1', CallSource.push), isTrue);
      expect(d.shouldShow('u1', CallSource.socket), isFalse);
    });

    test('push-и дертар баъди «Рад» зангро аз нав садо намедиҳад', () {
      expect(d.shouldShow('u1', CallSource.socket), isTrue);
      d.finish('u1');
      now = now.add(const Duration(seconds: 3));
      expect(d.shouldShow('u1', CallSource.push), isFalse);
    });

    test('занги НАВ тавассути сокет баъди «Рад» фавран нишон дода мешавад', () {
      d.shouldShow('u1', CallSource.socket);
      d.finish('u1');
      now = now.add(const Duration(seconds: 3));
      expect(d.shouldShow('u1', CallSource.socket), isTrue);
    });

    test('баъди муддат push-и нав боз кор мекунад', () {
      d.shouldShow('u1', CallSource.socket);
      d.finish('u1');
      now = now.add(CallDedupe.tombstone + const Duration(seconds: 1));
      expect(d.shouldShow('u1', CallSource.push), isTrue);
    });

    test('занги фаромӯшшуда (бе finish) пас аз равзана мегузарад', () {
      d.shouldShow('u1', CallSource.push);
      now = now.add(CallDedupe.ringWindow + const Duration(seconds: 1));
      expect(d.shouldShow('u1', CallSource.push), isTrue);
    });

    test('зангзанандагони гуногун ба ҳам халал намерасонанд', () {
      expect(d.shouldShow('u1', CallSource.socket), isTrue);
      expect(d.shouldShow('u2', CallSource.push), isTrue);
      expect(d.isActive('u1'), isTrue);
      expect(d.shouldShow('', CallSource.socket), isFalse);
    });
  });

  group('чати кушода', () {
    test('chatId-и «a_b» ҳарду иштирокчиро дорад', () {
      expect(ActiveChat.chatHasPeer('a_b', 'a'), isTrue);
      expect(ActiveChat.chatHasPeer('a_b', 'b'), isTrue);
      expect(ActiveChat.chatHasPeer('a_b', 'c'), isFalse);
      expect(ActiveChat.chatHasPeer('', 'a'), isFalse);
      expect(ActiveChat.chatHasPeer('a_b', ''), isFalse);
      // Шиносаи қисман монанд набояд мувофиқ ояд.
      expect(ActiveChat.chatHasPeer('ab_cd', 'a'), isFalse);
    });
  });

  group('садои каналҳо', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsState.instance.setLang('tj');
    });

    test('шиносаҳо бо сервер мувофиқанд (backend/notify/kind.go)', () {
      expect(NotificationChannels.messages, 'messages_v2');
      expect(NotificationChannels.social, 'social_v2');
      expect(NotificationChannels.calls, 'calls_v2');
    });

    test('шиносаҳои кӯҳна ба навашон мераванд', () {
      expect(NotificationChannels.resolve('messages'),
          NotificationChannels.messages);
      expect(NotificationChannels.resolve('social'),
          NotificationChannels.social);
      expect(NotificationChannels.resolve(NotificationChannels.calls),
          NotificationChannels.calls);
    });

    test('паём, иҷтимоӣ ва занг садоҳои ГУНОГУН доранд', () {
      final byId = {for (final c in NotificationChannels.all()) c.id: c};
      String? soundOf(String id) =>
          (byId[id]!.sound as RawResourceAndroidNotificationSound?)?.sound;
      final sounds = {
        soundOf(NotificationChannels.messages),
        soundOf(NotificationChannels.social),
        soundOf(NotificationChannels.calls),
      };
      expect(sounds, {'raonson_message', 'raonson_social', 'raonson_ringtone'});
      expect(byId[NotificationChannels.calls]!.importance, Importance.max);
    });

    test('канали кӯҳна дубора сохта намешавад', () {
      final ids = NotificationChannels.all().map((c) => c.id).toSet();
      for (final old in NotificationChannels.legacy) {
        expect(ids.contains(old), isFalse, reason: old);
      }
    });
  });

  group('матнҳои занг', () {
    test('ҳар се забон ҳамаи калидҳоро доранд', () async {
      SharedPreferences.setMockInitialValues({});
      const keys = [
        'voice', 'video', 'calling', 'accept', 'decline', 'missed',
        'callBack', 'channel', 'channelDesc', 'unknown',
      ];
      final seen = <String>{};
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in keys) {
          expect(CallStrings.t(k), isNot(k), reason: '$lang: $k');
        }
        seen.add(CallStrings.t('accept'));
      }
      expect(seen.length, 3);
      await AppSettingsState.instance.setLang('tj');
      expect(CallStrings.t('missedFrom', {'name': 'ali'}), contains('ali'));
    });
  });
}
