import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/music/feed_audio.dart';

// Камбудиҳое, ки КОРБАР бо APK-и воқеӣ ёфт — на тест.
//
// ═══════════════════════════════════════════════════════════════════
//  1. Пост → стори: дар стори ТАНҲО ГРАДИЕНТ буд, расми пост набуд.
//  2. Музикаи пост худаш намехонд — play ва stop заданӣ буд.
//  3. Номи музика дар ЗЕРИ пост буд, на дар боло мисли Instagram.
//  4. Баландгӯяк дар тарафи рости расм набуд.
//  5. Reels: барои садо аввал видеоро бас кардан лозим буд.
//  6. Видеоҳои файлашон нестшуда дар explore то абад мемонданд.
//
//  Ҳар гурӯҳ ин ҷо месанҷад, ки ҳамон камбудӣ барнагардад.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('1. пост → стори', () {
    late String src;
    setUpAll(() => src = _read('lib/create/share_to_story.dart'));

    test('расм ПЕШ аз кашидан бор мешавад, на дар замина', () {
      // `Image.network` дар кадри аввал чизе намекашад; карт танҳо
      // ЯК кадр дорад → дар стори расм намебуд.
      final card = src.substring(src.indexOf('class _StoryCard'));
      final cardBody = card.substring(0, card.indexOf('class _Preview'));
      expect(cardBody.contains('Image.network'), isFalse,
          reason: 'карт боз `Image.network` дорад — дар стори танҳо '
              'градиент мемонад');
      expect(cardBody, contains('RawImage'));
      expect(src, contains('Future<ui.Image?> _loadImage('));
      expect(src, contains('instantiateImageCodec'));
    });

    test('расмҳои боршуда озод мешаванд', () {
      expect(src, contains('media?.dispose()'));
      expect(src, contains('avatar?.dispose()'));
    });

    test('замина — ҳамон расм, на ранги бегона', () {
      expect(src, contains('ImageFilter.blur'));
    });
  });

  group('2. як суруд дар як вақт', () {
    // Санҷиши ҲАҚИҚӢ — худи код, на матни он.
    final a = FeedAudio.instance;
    setUp(() => a.owner.value = null);

    test('пости намоён садоро мегирад', () {
      a.claim('p1');
      expect(a.isOwner('p1'), isTrue);
    });

    test('пости нав пешинаро хомӯш мекунад — ду суруд ҳамзамон НЕ', () {
      a.claim('p1');
      a.claim('p2');
      expect(a.isOwner('p1'), isFalse);
      expect(a.isOwner('p2'), isTrue);
    });

    test('пости аз экран рафта садои пости НАВро хомӯш намекунад', () {
      // Ҳангоми варақ задан: p2 намоён шуд, баъд p1 аз экран рафт.
      a.claim('p1');
      a.claim('p2');
      a.release('p1');
      expect(a.isOwner('p2'), isTrue,
          reason: 'p1 садои p2-ро бурид — музика ҳангоми варақ '
              'задан қатъ мешуд');
    });

    test('охирин пост рафт — садо нест', () {
      a.claim('p1');
      a.release('p1');
      expect(a.owner.value, isNull);
    });
  });

  group('3–4. пост мисли Instagram', () {
    late String card;
    setUpAll(() => card = _read('lib/feed/post/post_card.dart'));

    test('номи музика дар САРЛАВҲА аст', () {
      expect(card, contains('style: MusicBarStyle.header'));
      final header = card.indexOf('// ── HEADER');
      final media = card.indexOf('// ── MEDIA + Double-tap heart');
      final music = card.indexOf('MusicBarStyle.header');
      expect(music > header && music < media, isTrue,
          reason: 'сатри музика берун аз сарлавҳа аст');
    });

    test('дар зери пост сатри дуюми музика НЕСТ', () {
      // Танҳо як MusicBar дар тамоми корт.
      expect('MusicBar('.allMatches(card).length, 1);
    });

    test('музика худаш сар мешавад, вақте пост дар экран аст', () {
      expect(card, contains('VisibilityDetector('));
      expect(card, contains('FeedAudio.instance.claim(widget.post.id)'));
      expect(card, contains('autoPlay: _audioOn'));
    });

    test('садо дар замина ва дар таби дигар бас мешавад', () {
      final i = card.indexOf('bool get _audioOn');
      final body = card.substring(i, i + 260);
      expect(body, contains('widget.isActive'));
      expect(body, contains('foreground.value'));
    });

    test('корт ҳангоми нест шудан садоро озод мекунад', () {
      final i = card.indexOf('void dispose()');
      expect(card.substring(i, i + 500),
          contains('FeedAudio.instance.release(widget.post.id)'));
    });

    test('баландгӯяк дар тарафи РОСТИ расм', () {
      final i = card.indexOf('Баландгӯяк — ТАРАФИ РОСТ');
      expect(i, greaterThan(0));
      final body = card.substring(i, i + 900);
      expect(body, contains('right: 10'));
      expect(body, contains('toggleMuted()'));
    });
  });

  group('MusicBar ба намоён шудан ҷавоб медиҳад', () {
    late String bar;
    setUpAll(() => bar = _read('lib/core/music/music_bar.dart'));

    test('autoPlay аз false ба true — садо сар мешавад', () {
      // Пеш танҳо тағйири `paused` дида мешуд; пости баъдтар
      // намоёншуда ҳеҷ гоҳ намехонд.
      expect(bar, contains('bool get _shouldPlay'));
      final i = bar.indexOf('void didUpdateWidget(MusicBar old)');
      final body = bar.substring(i, i + 1100);
      expect(body, contains('final was = old.autoPlay && !old.paused'));
      expect(body, contains('_start()'));
    });
  });

  group('5. Reels мисли Instagram', () {
    late String reels;
    setUpAll(() => reels = _read('lib/reels/reels_feed/reels_screen.dart'));

    test('як зарба — садо, на истодан', () {
      expect(reels, contains('onTap: _paused ? _togglePause : _tapToggleMute'));
    });

    test('пахш карда нигоҳ доштан — истодан', () {
      expect(reels, contains('onLongPressStart: (_) => _holdStart()'));
      expect(reels, contains('onLongPressEnd: (_) => _holdEnd()'));
      expect(reels, contains('onLongPressCancel: _holdEnd'));
    });

    test('таймери нишони садо озод мешавад', () {
      expect(reels, contains('_flashTimer?.cancel();\n    _sendWatchTime();'));
    });
  });

  group('6. видеоҳои файлашон нест', () {
    test('плитка худро хориҷ мекунад ва серверро огоҳ мекунад', () {
      final search = _read('lib/search/search_screen.dart');
      expect(search, contains('onFailed: onBroken'));
      expect(search, contains("'/reels/\$id/media-check'"));
      final frame = _read('lib/core/ui/video_frame.dart');
      expect(frame, contains('widget.onFailed?.call()'));
    });

    test('сервер ба телефон бовар намекунад — худаш месанҷад', () {
      final go = _read('backend/handlers/media_check.go');
      expect(go, contains('SELECT COALESCE(video_url'),
          reason: 'суроға бояд аз БАЗА гирифта шавад, на аз телефон');
      expect(go, contains('onOurStorage('));
    });
  });
}
