// test/upload_notifier_test.dart
// Огоҳиномаи боргузорӣ: throttle, харитаи марҳилаҳо, таъхир.
//
// Плагин иштирок намекунад — [UploadNotificationSink]-и сохта ҳамаи
// даъватҳоро сабт мекунад.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/notifications/notification_channels.dart';
import 'package:raonson/core/notifications/upload_notifier.dart';
import 'package:raonson/create/upload/upload_manager.dart';

class _Call {
  _Call(this.op, this.id, [this.title, this.percent, this.body]);
  final String op;
  final int id;
  final String? title;
  final int? percent;
  final String? body;
  @override
  String toString() => '$op($id, $title, $percent, $body)';
}

class _FakeSink implements UploadNotificationSink {
  final calls = <_Call>[];

  List<int?> get percents =>
      calls.where((c) => c.op == 'progress').map((c) => c.percent).toList();

  @override
  Future<void> progress(int id, String title, int? percent) async =>
      calls.add(_Call('progress', id, title, percent));

  @override
  Future<void> done(int id, String title, Duration linger) async =>
      calls.add(_Call('done', id, title));

  @override
  Future<void> failed(int id, String title, String body) async =>
      calls.add(_Call('failed', id, title, null, body));

  @override
  Future<void> cancel(int id) async => calls.add(_Call('cancel', id));
}

/// Соати дастӣ — вақт танҳо бо [advance] мегузарад.
class _Clock {
  DateTime now = DateTime(2026, 1, 1);
  void advance(int ms) => now = now.add(Duration(milliseconds: ms));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  group('фоиз ва марҳилаҳо', () {
    test('toPercent маҳдуд ва бехатар', () {
      expect(toPercent(0), 0);
      expect(toPercent(0.455), 45);
      expect(toPercent(1), 100);
      expect(toPercent(1.7), 100);
      expect(toPercent(-0.2), 0);
      expect(toPercent(double.nan), 0);
      expect(toPercent(double.infinity), 0);
    });

    test('phase ҳиссаи марҳиларо ба умумӣ табдил медиҳад', () {
      // Пост: бор кардан 0.30 → 0.85.
      expect(phase(0.3, 0.85, 0), closeTo(0.3, 1e-9));
      expect(phase(0.3, 0.85, 0.5), closeTo(0.575, 1e-9));
      expect(phase(0.3, 0.85, 1), closeTo(0.85, 1e-9));
      // Берун аз 0..1 маҳдуд мешавад.
      expect(phase(0.3, 0.85, 2), closeTo(0.85, 1e-9));
      expect(phase(0.3, 0.85, -1), closeTo(0.3, 1e-9));
      expect(phase(0.3, 0.85, double.nan), closeTo(0.3, 1e-9));
    });

    test('MonotonicProgress ба қафо намеравад (retry)', () {
      final out = <double>[];
      final m = MonotonicProgress(out.add);
      m(0.2);
      m(0.5);
      m(0.1); // retry аз нав
      m(0.5);
      m(0.7);
      m(double.nan);
      m(3);
      expect(out, [0.2, 0.5, 0.7, 1.0]);
    });
  });

  group('ProgressThrottle', () {
    late _Clock clock;
    late ProgressThrottle t;
    setUp(() {
      clock = _Clock();
      t = ProgressThrottle(clock: () => clock.now);
    });

    test('аввалин ҳамеша мегузарад', () {
      expect(t.shouldEmit(0), isTrue);
      expect(t.lastPercent, 0);
    });

    test('бе вақти кофӣ рад мешавад, ҳатто бо қадами калон', () {
      t.shouldEmit(0);
      clock.advance(100);
      expect(t.shouldEmit(40), isFalse);
      clock.advance(250); // 350 ms
      expect(t.shouldEmit(40), isTrue);
    });

    test('қадами хурд то 1 с интизор мешавад', () {
      t.shouldEmit(10);
      clock.advance(400);
      expect(t.shouldEmit(11), isFalse, reason: '< 3% ва < 1 с');
      expect(t.shouldEmit(13), isTrue, reason: '≥ 3% ва ≥ 300 ms');
      clock.advance(1000);
      expect(t.shouldEmit(14), isTrue, reason: 'баъди 1 с ҳатто 1%');
    });

    test('ҳамон фоиз ё камтар ҳеҷ гоҳ', () {
      t.shouldEmit(50);
      clock.advance(5000);
      expect(t.shouldEmit(50), isFalse);
      expect(t.shouldEmit(20), isFalse);
      expect(t.lastPercent, 50);
    });

    test('100% фавран мегузарад', () {
      t.shouldEmit(10);
      clock.advance(1);
      expect(t.shouldEmit(100), isTrue);
    });

    test('ҷараёни зич ≤ ~3.4 навсозӣ дар як сония', () {
      // 10 000 порча дар 10 с (ҳар 1 ms), 0→99%.
      var emitted = 0;
      for (var i = 0; i < 10000; i++) {
        if (t.shouldEmit(i * 100 ~/ 10000)) emitted++;
        clock.advance(1);
      }
      expect(emitted, lessThanOrEqualTo(35));
      expect(emitted, greaterThanOrEqualTo(20));
      expect(t.lastPercent, greaterThanOrEqualTo(96));
    });
  });

  group('UploadNotifier', () {
    late _Clock clock;
    late _FakeSink sink;
    late UploadNotifier n;
    setUp(() {
      clock = _Clock();
      sink = _FakeSink();
      n = UploadNotifier(sink: sink, clock: () => clock.now);
    });

    test('оғоз → номуайян бо сарлавҳаи тоҷикӣ', () async {
      final id = n.start(UploadKind.story);
      await n.flush();
      expect(sink.calls.single.op, 'progress');
      expect(sink.calls.single.id, id);
      expect(sink.calls.single.title, 'Сторис бор мешавад…');
      expect(sink.calls.single.percent, isNull);
    });

    test('пешрафт throttle мешавад ва «Нашр шуд» меояд', () async {
      final id = n.start(UploadKind.post);
      n.progress(id, 0.08);
      clock.advance(50);
      n.progress(id, 0.20); // хеле зуд — рад
      clock.advance(300);
      n.progress(id, 0.45);
      clock.advance(300);
      n.progress(id, 0.46); // қадами хурд — рад
      n.progress(id, 0.30); // ба қафо — рад
      n.done(id);
      await n.flush();
      expect(sink.percents, [null, 8, 45]);
      expect(sink.calls.last.op, 'done');
      expect(sink.calls.last.title, 'Нашр шуд');
      expect(n.activeCount, 0);
    });

    test('номуайян баъди фоизи воқеӣ дигар нишон дода намешавад', () async {
      final id = n.start(UploadKind.reel);
      n.progress(id, 0.1);
      n.progress(id, null);
      await n.flush();
      expect(sink.percents, [null, 10]);
    });

    test('хато → «Бор нашуд», пас аз он ҳеҷ навсозӣ', () async {
      final id = n.start(UploadKind.reel);
      n.failed(id);
      clock.advance(5000);
      n.progress(id, 0.9);
      n.done(id);
      await n.flush();
      expect(sink.calls.map((c) => c.op), ['progress', 'failed']);
      expect(sink.calls.last.title, 'Бор нашуд');
      expect(sink.calls.last.body, 'Reel бор мешавад…');
    });

    test('чат: кори тез (пеш аз таъхир) ҳеҷ огоҳинома намедиҳад', () async {
      final id = n.start(UploadKind.voice,
          delay: const Duration(milliseconds: 60));
      n.progress(id, 0.5);
      n.done(id, announce: false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await n.flush();
      expect(sink.calls, isEmpty);
    });

    test('чат: хатои тез низ хомӯш (экрани чат худаш нишон медиҳад)',
        () async {
      final id = n.start(UploadKind.photo,
          delay: const Duration(milliseconds: 60));
      n.failed(id);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await n.flush();
      expect(sink.calls, isEmpty);
    });

    test('чат: кори дароз баъди таъхир бо фоизи охирин пайдо мешавад',
        () async {
      final id = n.start(UploadKind.voice,
          delay: const Duration(milliseconds: 30));
      n.progress(id, 0.2);
      n.progress(id, 0.4);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await n.flush();
      expect(sink.calls.single.title, 'Паёми овозӣ фиристода мешавад…');
      expect(sink.calls.single.percent, 40);

      clock.advance(400);
      n.progress(id, 0.9);
      n.done(id, announce: false);
      await n.flush();
      expect(sink.percents, [40, 90]);
      // Паём дар чат аст — танҳо пок мешавад, бе «Нашр шуд».
      expect(sink.calls.last.op, 'cancel');
    });

    test('чат: пеш аз таъхир пешрафт номаълум → номуайян', () async {
      n.start(UploadKind.file, delay: const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await n.flush();
      expect(sink.calls.single.percent, isNull);
    });

    test('шиносаҳо ҷудо; ду боргузорӣ ҳамзамон', () async {
      final a = n.start(UploadKind.post);
      final b = n.start(UploadKind.story);
      expect(a, isNot(b));
      n.progress(a, 0.5);
      n.done(b);
      await n.flush();
      expect(n.activeCount, 1);
      n.done(a);
      expect(n.activeCount, 0);
    });

    test('track: натиҷа ва хато', () async {
      final r = await n.track(UploadKind.avatar, (p) async {
        p(0.5);
        return 'url';
      }, announce: false);
      expect(r, 'url');
      await n.flush();
      expect(sink.calls.map((c) => c.op), ['progress', 'progress', 'cancel']);

      sink.calls.clear();
      await expectLater(
          n.track<String>(UploadKind.avatar, (_) async => throw Exception('x')),
          throwsException);
      await n.flush();
      expect(sink.calls.last.op, 'failed');
    });

    test('хатои плагин ба боргузорӣ намерасад', () async {
      final bad = UploadNotifier(sink: _ThrowingSink());
      final id = bad.start(UploadKind.post);
      bad.progress(id, 0.5);
      bad.done(id);
      await bad.flush();
      expect(bad.activeCount, 0);
    });
  });

  group('пешрафти байтӣ', () {
    test('ProgressMultipartRequest байтҳоро то contentLength мешуморад',
        () async {
      final seen = <int>[];
      var total = -1;
      final req = ProgressMultipartRequest(
          'POST', Uri.parse('https://example.invalid/upload'),
          onBytes: (sent, t) {
        seen.add(sent);
        total = t;
      })
        ..files.add(http.MultipartFile.fromBytes(
            'file', List<int>.filled(200 * 1024, 7), filename: 'a.jpg'));
      final bytes = await req.finalize().toBytes();
      expect(total, bytes.length);
      expect(seen.last, bytes.length);
      expect(seen.length, greaterThan(1));
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
    });
  });

  group('сарлавҳа ва канал', () {
    test('ҳар навъ дар ҳар се забон тарҷума дорад', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in UploadKind.values) {
          expect(uploadTitle(k), isNot(startsWith('upl.')),
              reason: '$lang/${k.name}');
        }
        for (final key in ['upl.done', 'upl.failed', 'upl.preparing',
            'nch.uploads', 'nch.uploadsDesc']) {
          expect(tr(key), isNot(key), reason: '$lang/$key');
        }
      }
      await AppSettingsState.instance.setLang('ru');
      expect(uploadTitle(UploadKind.story), 'История загружается…');
    });

    test('навъи чат аз васеъшавӣ', () {
      expect(chatUploadKind('/a/voice.m4a'), UploadKind.voice);
      expect(chatUploadKind('/a/v.MP4'), UploadKind.video);
      expect(chatUploadKind('/a/p.jpg'), UploadKind.photo);
      expect(chatUploadKind('/a/doc.pdf'), UploadKind.file);
    });

    test('канал ором ва ҷудо аз каналҳои сервер', () {
      final ch = NotificationChannels.uploadsChannel();
      expect(ch.id, NotificationChannels.uploads);
      expect(ch.importance, Importance.low);
      expect(ch.playSound, isFalse);
      expect(ch.enableVibration, isFalse);
      expect(NotificationChannels.all().map((c) => c.id),
          isNot(contains(NotificationChannels.uploads)));
    });
  });
}

class _ThrowingSink implements UploadNotificationSink {
  @override
  Future<void> progress(int id, String title, int? percent) =>
      throw StateError('no permission');
  @override
  Future<void> done(int id, String title, Duration linger) async =>
      throw StateError('no permission');
  @override
  Future<void> failed(int id, String title, String body) =>
      throw StateError('no permission');
  @override
  Future<void> cancel(int id) => throw StateError('no permission');
}
