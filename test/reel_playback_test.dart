// Пахши Reels дар интернети суст: интихоби сифат, паст кардан ҳангоми
// истодан, такрор бо таъхир, нақшаи пешбор, ҷойи тамошо, прокси-и кэш.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/reels/offline/offline_reels.dart';
import 'package:raonson/reels/playback/playback_policy.dart';
import 'package:raonson/reels/playback/video_cache_proxy.dart';

const full = ReelSources(
  hls: 'https://cdn/r/hls/s/master.m3u8',
  hlsLow: 'https://cdn/r/hls/s/240p/index.m3u8',
  high: 'https://cdn/v.mp4',
  low: 'https://cdn/v_low.mp4',
  preview: 'https://cdn/r/hls/s/preview.mp4',
);
const mp4Only = ReelSources(high: 'https://cdn/v.mp4', low: 'https://cdn/v_low.mp4');

void main() {
  group('PlaybackPolicy.choose', () {
    test('HLS авлотар аст (плеер худаш сифатро иваз мекунад)', () {
      final c = PlaybackPolicy.choose(full, dataSaver: false, kind: NetKind.cellular, kbps: 500)!;
      expect(c.kind, SourceKind.hls);
      expect(c.isHls, isTrue);
    });

    test('Data Saver → танҳо зинаи пасттарини HLS', () {
      final c = PlaybackPolicy.choose(full, dataSaver: true, kind: NetKind.wifi, kbps: 50000)!;
      expect(c.url, full.hlsLow);
    });

    test('паст кардан: HLS → HLS-и паст → MP4-и паст → MP4-и баланд (захира)', () {
      final l = PlaybackPolicy.ladder(full, dataSaver: false, kind: NetKind.wifi);
      expect(l.map((e) => e.kind), [SourceKind.hls, SourceKind.hlsLow, SourceKind.mp4Low, SourceKind.mp4High]);
      expect(PlaybackPolicy.choose(full, dataSaver: false, kind: NetKind.wifi, level: 1)!.url, full.hlsLow);
      // Аз охир гузашта намешавад.
      expect(PlaybackPolicy.choose(full, dataSaver: false, kind: NetKind.wifi, level: 99)!.level, 3);
    });

    test('бе HLS — MP4 аз рӯи суръати ЧЕНШУДА', () {
      expect(PlaybackPolicy.choose(mp4Only, dataSaver: false, kind: NetKind.wifi, kbps: 800)!.url, mp4Only.low,
          reason: 'Wi-Fi-и суст ҳам суст аст');
      expect(PlaybackPolicy.choose(mp4Only, dataSaver: false, kind: NetKind.cellular, kbps: 6000)!.url, mp4Only.high,
          reason: '4G-и тез — сифати баланд');
    });

    test('суръат номаълум → аз рӯи навъи пайваст', () {
      expect(PlaybackPolicy.choose(mp4Only, dataSaver: false, kind: NetKind.wifi)!.url, mp4Only.high);
      expect(PlaybackPolicy.choose(mp4Only, dataSaver: false, kind: NetKind.cellular)!.url, mp4Only.low);
    });

    test('stall → паст: MP4-и баланд → MP4-и паст', () {
      final c = PlaybackPolicy.choose(mp4Only, dataSaver: false, kind: NetKind.wifi, kbps: 9000, level: 1)!;
      expect(c.url, mp4Only.low);
    });

    test('reel-и кӯҳна бе video_url_low', () {
      const only = ReelSources(high: 'https://cdn/v.mp4');
      final c = PlaybackPolicy.choose(only, dataSaver: true, kind: NetKind.cellular, kbps: 100)!;
      expect(c.url, only.high);
      expect(PlaybackPolicy.choose(const ReelSources(), dataSaver: false, kind: NetKind.wifi), isNull);
    });
  });

  group('Data Saver', () {
    test('Хомӯш / Фаъол / Худкор', () {
      expect(PlaybackPolicy.dataSaverActive(DataSaverMode.off, NetKind.cellular, 100), isFalse);
      expect(PlaybackPolicy.dataSaverActive(DataSaverMode.on, NetKind.wifi, 50000), isTrue);
      expect(PlaybackPolicy.dataSaverActive(DataSaverMode.auto, NetKind.cellular, 600), isTrue);
      expect(PlaybackPolicy.dataSaverActive(DataSaverMode.auto, NetKind.cellular, null), isTrue);
      expect(PlaybackPolicy.dataSaverActive(DataSaverMode.auto, NetKind.cellular, 8000), isFalse);
      expect(PlaybackPolicy.dataSaverActive(DataSaverMode.auto, NetKind.wifi, 300), isFalse,
          reason: 'Худкор — танҳо интернети мобилӣ');
    });

    test('сатр → ҳолат', () {
      expect(dataSaverFromString('on'), DataSaverMode.on);
      expect(dataSaverFromString('auto'), DataSaverMode.auto);
      expect(dataSaverFromString(null), DataSaverMode.off);
      expect(dataSaverFromString('xx'), DataSaverMode.off);
    });
  });

  group('BandwidthEstimator', () {
    test('EWMA; интиқоли хурд ҳисоб намешавад', () {
      final b = BandwidthEstimator(alpha: 0.5);
      b.add(1000, const Duration(seconds: 1)); // хурд
      expect(b.kbps, isNull);
      b.add(250000, const Duration(seconds: 1)); // 2000 kbps
      expect(b.kbps, closeTo(2000, 1));
      b.add(50000, const Duration(seconds: 1)); // 400 kbps
      expect(b.kbps, closeTo(1200, 1));
      expect(PlaybackPolicy.isSlow(NetKind.wifi, b.kbps), isFalse);
      b.add(50000, const Duration(seconds: 1));
      expect(PlaybackPolicy.isSlow(NetKind.wifi, b.kbps), isTrue);
      b.reset();
      expect(b.kbps, isNull);
    });
  });

  group('StallMonitor', () {
    final t0 = DateTime(2026);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('нишон танҳо баъд аз >400 мс', () {
      final m = StallMonitor()..markStarted();
      m.onBuffering(true, at(0));
      expect(m.indicatorVisible(at(300)), isFalse);
      expect(m.indicatorVisible(at(401)), isTrue);
      m.onBuffering(false, at(450));
      expect(m.indicatorVisible(at(500)), isFalse);
    });

    test('истодани ибтидоӣ (то кадри аввал) сифатро паст намекунад', () {
      final m = StallMonitor();
      m.onBuffering(true, at(0));
      expect(m.onBuffering(false, at(5000)), isFalse);
      expect(m.stuck(at(6000)), isFalse);
    });

    test('ду истодан дар 30 с → паст', () {
      final m = StallMonitor()..markStarted();
      m.onBuffering(true, at(0));
      expect(m.onBuffering(false, at(700)), isFalse);
      m.onBuffering(true, at(10000));
      expect(m.onBuffering(false, at(10800)), isTrue);
    });

    test('ҷаҳишҳои хурд (<400 мс) ҳисоб намешаванд; дур аз ҳам — не', () {
      final m = StallMonitor()..markStarted();
      for (var i = 0; i < 5; i++) {
        m.onBuffering(true, at(i * 1000));
        expect(m.onBuffering(false, at(i * 1000 + 200)), isFalse);
      }
      m.onBuffering(true, at(0));
      m.onBuffering(false, at(600));
      m.onBuffering(true, at(40000));
      expect(m.onBuffering(false, at(40600)), isFalse, reason: 'берун аз равзанаи 30 с');
    });

    test('истодани дароз → паст ҳатто пеш аз охираш (таймер)', () {
      final m = StallMonitor()..markStarted();
      m.onBuffering(true, at(0));
      expect(m.stuck(at(2000)), isFalse);
      expect(m.stuck(at(2600)), isTrue);
      expect(m.stuck(at(3000)), isFalse, reason: 'як бор, на ҳар тик');
      expect(m.onBuffering(false, at(3100)), isFalse);
    });
  });

  group('RetryBackoff', () {
    test('1 с, 2 с, 4 с, 8 с, баъд бас — ҳеҷ гоҳ ҳалқаи тез', () {
      final b = RetryBackoff(jitter: 0);
      expect([b.next(), b.next(), b.next(), b.next()],
          [for (final s in [1, 2, 4, 8]) Duration(seconds: s)]);
      expect(b.next(), isNull);
      expect(b.exhausted, isTrue);
      b.reset();
      expect(b.next(), const Duration(seconds: 1));
    });

    test('ҳадди боло ва jitter', () {
      final b = RetryBackoff(maxAttempts: 10, max: const Duration(seconds: 5),
          jitter: 0.2, random: math.Random(1));
      final ds = [for (var i = 0; i < 10; i++) b.next()!];
      for (final d in ds) {
        expect(d.inMilliseconds, inInclusiveRange(800, 6000));
        expect(d.inMilliseconds, greaterThan(0));
      }
      expect(ds.last.inMilliseconds, inInclusiveRange(4000, 6000));
    });
  });

  group('PreloadPlanner', () {
    test('муқаррарӣ: 2 reel-и навбатӣ (≤3 плеери зинда бо ҷорӣ)', () {
      final p = PreloadPlanner.plan(current: 4, count: 20, slow: false, dataSaver: false);
      expect(p.preload, [5, 6]);
      expect(p.preload.length + 1, lessThanOrEqualTo(PreloadPlanner.maxLive));
      expect(p.prefetchPreview, [5, 6]);
    });

    test('Data Saver → танҳо 1', () {
      final p = PreloadPlanner.plan(current: 0, count: 20, slow: false, dataSaver: true);
      expect(p.preload, [1]);
      expect(p.prefetchPreview, [1]);
    });

    test('интернети суст → пешбор қатъ, танҳо preview-и хурд', () {
      final p = PreloadPlanner.plan(current: 0, count: 20, slow: true, dataSaver: false);
      expect(p.preload, isEmpty);
      expect(p.prefetchPreview, [1]);
    });

    test('охири рӯйхат ва reel-и embed', () {
      expect(PreloadPlanner.plan(current: 19, count: 20, slow: false, dataSaver: false).preload, isEmpty);
      final p = PreloadPlanner.plan(current: 0, count: 20, slow: false, dataSaver: false,
          playable: (j) => j != 1);
      expect(p.preload, [2]);
    });

    test('плеерҳои дур ва қаблӣ озод мешаванд, ҷорӣ — не', () {
      final p = PreloadPlanner.plan(current: 5, count: 20, slow: false, dataSaver: false);
      expect(p.evict([2, 4, 5, 6, 7, 9], 5).toList(), [2, 4, 9]);
      final slow = PreloadPlanner.plan(current: 5, count: 20, slow: true, dataSaver: false);
      expect(slow.evict([5, 6, 7], 5).toList(), [6, 7]);
    });
  });

  group('ResumePositions', () {
    test('ҷой нигоҳ дошта ва як бор гирифта мешавад', () {
      final r = ResumePositions();
      r.save('a', const Duration(seconds: 7), const Duration(seconds: 30));
      expect(r.take('a'), const Duration(seconds: 7));
      expect(r.take('a'), isNull);
    });

    test('оғоз ё қариб охир → аз аввал', () {
      final r = ResumePositions();
      r.save('a', const Duration(milliseconds: 300), const Duration(seconds: 30));
      r.save('b', const Duration(milliseconds: 29500), const Duration(seconds: 30));
      expect(r.peek('a'), isNull);
      expect(r.peek('b'), isNull);
    });

    test('LRU маҳдуд', () {
      final r = ResumePositions(capacity: 3);
      for (final id in ['a', 'b', 'c', 'd']) {
        r.save(id, const Duration(seconds: 5), const Duration(seconds: 30));
      }
      expect(r.length, 3);
      expect(r.peek('a'), isNull);
      expect(r.peek('d'), isNotNull);
    });
  });

  group('ReelModel', () {
    test('hlsUrl / hlsLowUrl / previewUrl хонда ва навишта мешаванд', () {
      final r = ReelModel.fromJson({
        '_id': 'r1', 'videoUrl': 'https://cdn/v.mp4',
        'hlsUrl': full.hls, 'hlsLowUrl': full.hlsLow, 'previewUrl': full.preview,
        'renditionsReady': true,
      });
      expect(r.hlsUrl, full.hls);
      final back = ReelModel.fromJson(r.toJson());
      expect([back.hlsUrl, back.hlsLowUrl, back.previewUrl], [full.hls, full.hlsLow, full.preview]);
      expect(ReelModel.fromJson({'_id': 'x', 'videoUrl': 'v'}).hlsUrl, '');
    });

    test('офлайн: Data Saver → нусхаи паст', () {
      const u = UserModel(id: 'u', username: 'a', avatar: '', verified: false,
          isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0);
      const r = ReelModel(id: 'r', videoUrl: 'https://h.mp4', videoUrlLow: 'https://l.mp4',
          caption: '', user: u, likesCount: 0, commentsCount: 0, isLiked: false);
      expect(offlineSourceFor(r, dataSaver: true), 'https://l.mp4');
      expect(offlineSourceFor(r, dataSaver: false), 'https://h.mp4');
    });
  });

  group('VideoCacheProxy', () {
    late HttpServer origin;
    late Directory dir;
    late VideoCacheProxy proxy;
    final hits = <String>[];
    final body = List<int>.generate(300 * 1024, (i) => i % 251);
    final transfers = <int>[];

    setUp(() async {
      hits.clear();
      transfers.clear();
      dir = await Directory.systemTemp.createTemp('rvc');
      origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin.listen((req) async {
        hits.add(req.uri.path);
        if (req.uri.path.endsWith('master.m3u8')) {
          req.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
          req.response.write('#EXTM3U\n240p/index.m3u8\n');
        } else if (req.uri.path.endsWith('.ts')) {
          req.response.headers.contentType = ContentType('video', 'mp2t');
          req.response.contentLength = body.length;
          req.response.add(body);
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
      proxy = VideoCacheProxy(dir: dir, maxBytes: 700 * 1024, preloadBudget: 64 * 1024,
          trickleEvery: const Duration(milliseconds: 40), onTransfer: (n, _) => transfers.add(n));
      await proxy.start();
    });

    tearDown(() async {
      await proxy.stop();
      await origin.close(force: true);
      await dir.delete(recursive: true);
    });

    String url(String p) => 'http://127.0.0.1:${origin.port}$p';

    Future<(int, List<int>, HttpHeaders)> get(Uri u, {String? range}) async {
      final c = HttpClient();
      final rq = await c.getUrl(u);
      if (range != null) rq.headers.set(HttpHeaders.rangeHeader, range);
      final rs = await rq.close();
      final b = await rs.fold<List<int>>([], (a, x) => a..addAll(x));
      c.close();
      return (rs.statusCode, b, rs.headers);
    }

    test('кэш: бори дуюм аз диск (бозтамошо бе трафик)', () async {
      proxy.setActive('r1');
      final u = proxy.wrap(url('/reels/r1/hls/s/240p/seg_000.ts'), group: 'r1');
      expect(u.host, '127.0.0.1');
      final (s1, b1, h1) = await get(u);
      expect(s1, 200);
      expect(b1, body);
      expect(h1.contentType?.mimeType, 'video/mp2t');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(proxy.isCached(url('/reels/r1/hls/s/240p/seg_000.ts')), isTrue);
      final (s2, b2, _) = await get(u);
      expect(s2, 200);
      expect(b2, body);
      expect(hits.where((h) => h.endsWith('seg_000.ts')).length, 1, reason: 'бори дуюм CDN занг намезанад');
      expect(transfers, isNotEmpty, reason: 'суръати воқеӣ чен шуд');
    });

    test('Range аз кэш', () async {
      proxy.setActive('r1');
      final u = proxy.wrap(url('/a/seg_001.ts'), group: 'r1');
      await get(u);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final (s, b, h) = await get(u, range: 'bytes=100-199');
      expect(s, 206);
      expect(b, body.sublist(100, 200));
      expect(h.value(HttpHeaders.contentRangeHeader), 'bytes 100-199/${body.length}');
      final (s2, _, _) = await get(u, range: 'bytes=999999999-');
      expect(s2, 416);
    });

    test('роҳҳои нисбии HLS аз прокси мегузаранд', () async {
      proxy.setActive('r1');
      final m = proxy.wrap(url('/reels/r1/hls/s/master.m3u8'), group: 'r1');
      final (s, b, _) = await get(m);
      expect(s, 200);
      expect(String.fromCharCodes(b), contains('240p/index.m3u8'));
      final variant = m.resolve('240p/seg_000.ts');
      expect(variant.host, '127.0.0.1');
      final (s2, b2, _) = await get(variant);
      expect(s2, 200);
      expect(b2.length, body.length);
    });

    test('reel-и пешакӣ: то буҷет тез, баъд қатра-қатра; фаъол → фавран', () async {
      proxy.setActive('current');
      final u = proxy.wrap(url('/p/seg_000.ts'), group: 'next');
      final sw = Stopwatch()..start();
      final f = get(u);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sw.elapsedMilliseconds, lessThan(5000));
      proxy.setActive('next'); // swipe → reel фаъол шуд
      final (s, b, _) = await f.timeout(const Duration(seconds: 5));
      expect(s, 200);
      expect(b, body);
      expect(transfers, isEmpty, reason: 'интиқоли маҳдуд суръатро вайрон намекунад');
    });

    test('буҷет 0 (интернети суст) → reel-и пешакӣ қариб ҳеҷ намегирад', () async {
      proxy.preloadBudget = 0;
      proxy.trickleEvery = const Duration(seconds: 1);
      proxy.setActive('current');
      final c = HttpClient();
      final rq = await c.getUrl(proxy.wrap(url('/q/seg_000.ts'), group: 'next'));
      final rs = await rq.close();
      var got = 0;
      final sub = rs.listen((x) => got += x.length);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(got, lessThanOrEqualTo(4 * 1024));
      await sub.cancel();
      c.close(force: true);
    });

    test('андозаи кэш маҳдуд (LRU)', () async {
      proxy.setActive('r');
      for (var i = 0; i < 4; i++) {
        await get(proxy.wrap(url('/l/seg_00$i.ts'), group: 'r'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(proxy.cachedBytes, lessThanOrEqualTo(700 * 1024));
      expect(proxy.isCached(url('/l/seg_003.ts')), isTrue);
      expect(proxy.isCached(url('/l/seg_000.ts')), isFalse);
    });

    test('хатои CDN кэш намешавад; prefetch', () async {
      proxy.setActive('r');
      final (s, _, _) = await get(proxy.wrap(url('/missing.mp4'), group: 'r'));
      expect(s, 404);
      expect(proxy.isCached(url('/missing.mp4')), isFalse);
      expect(await proxy.prefetch(url('/pv/seg_000.ts')), isTrue);
      expect(proxy.isCached(url('/pv/seg_000.ts')), isTrue);
      expect(await proxy.prefetch(url('/nope.mp4')), isFalse);
    });

    test('роҳи бе токен ё суроғаи ғайри-http рад мешавад', () async {
      final (s, _, _) = await get(Uri.parse('http://127.0.0.1:${proxy.port}/v/wrong/r/aGk/x.ts'));
      expect(s, 404);
      expect(proxy.wrap('file:///etc/passwd').scheme, 'file', reason: 'ба прокси намеравад');
    });

    test('кэш баъди бозоғоз аз диск хонда мешавад', () async {
      proxy.setActive('r');
      await get(proxy.wrap(url('/k/seg_000.ts'), group: 'r'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await proxy.stop();
      final p2 = VideoCacheProxy(dir: dir, maxBytes: 700 * 1024);
      await p2.start();
      expect(p2.cachedBytes, greaterThan(0));
      expect(p2.isCached(url('/k/seg_000.ts')), isTrue);
      await p2.stop();
    });
  });

  test('сарчашмаи reels_screen: плеерҳо тавассути ReelPlayback озод мешаванд', () {
    final src = File('lib/reels/reels_feed/reels_screen.dart').readAsStringSync();
    expect(src, contains('PreloadPlanner.plan('));
    expect(src, contains('ReelPlayback.controllerFor('));
    expect(src, contains('ReelPlayback.whenInitialized(pc)'),
        reason: 'initialize-и дуюм плеери дуюми платформа месохт');
    expect(RegExp(r'\b_preloaded\[k\]\?\.dispose\(\)').hasMatch(src), isFalse);
    unawaited(Future<void>.value());
  });
}
