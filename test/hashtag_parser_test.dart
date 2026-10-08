// test/hashtag_parser_test.dart
// Қоидаи хештег дар барнома = қоидаи сервер.
//
// Ҳамон файли санҷиширо мехонад, ки backend/hashtags/hashtags_test.go
// мехонад — агар яке аз ду тараф иваз шавад, ин тест меафтад.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/hashtags/hashtag_parser.dart';

void main() {
  final fixture = jsonDecode(
          File('backend/hashtags/testdata/hashtag_cases.json').readAsStringSync())
      as Map<String, dynamic>;

  group('паритет бо Go (hashtag_cases.json)', () {
    final cases = (fixture['extract'] as List).cast<Map<String, dynamic>>();
    test('файл пур аст', () => expect(cases.length, greaterThanOrEqualTo(15)));
    for (final c in cases) {
      test('extract: ${c['name']}', () {
        expect(extractHashtags(c['text'] as String),
            (c['tags'] as List).cast<String>());
      });
    }
    for (final c in (fixture['normalize'] as List).cast<Map<String, dynamic>>()) {
      test('normalize: «${c['in']}»', () {
        expect(normalizeHashtag(c['in'] as String), c['out']);
      });
    }
  });

  test('ҳарфҳои тоҷикӣ ҳарфи хештеганд', () {
    for (final cp in 'ҳҷқӯғӣҲҶҚӮҒӢёЁ'.runes) {
      expect(isHashtagChar(cp), isTrue, reason: String.fromCharCode(cp));
    }
    expect(extractHashtags('#ҷашни_наврӯз'), ['ҷашни_наврӯз']);
  });

  test('мавқеъҳо бо UTF-16 (emoji пеш аз хештег)', () {
    const text = '🎬 Кино #Душанбе!';
    final m = findHashtags(text).single;
    expect(text.substring(m.start, m.end), '#Душанбе');
    expect(m.raw, 'Душанбе');
    expect(m.tag, 'душанбе');
  });

  test('пешванди пешниҳод', () {
    expect(normalizeHashtagPrefix('#Ду'), 'ду');
    expect(normalizeHashtagPrefix('20'), '20');
    expect(normalizeHashtagPrefix(''), isNull);
    expect(normalizeHashtagPrefix('a b'), isNull);
  });

  group('linkSegments', () {
    test('хештег, зикр ва матн', () {
      final segs = linkSegments('Салом @ali.\n#Ҳисор, https://x.tj/#no');
      final kinds = segs.map((s) => s.kind).toList();
      expect(kinds, [
        LinkKind.text, LinkKind.mention, LinkKind.text,
        LinkKind.hashtag, LinkKind.text,
      ]);
      expect(segs[1].value, 'ali');
      expect(segs[3].text, '#Ҳисор');
      expect(segs[3].value, 'ҳисор');
      // Матни пурра бетағйир барқарор мешавад.
      expect(segs.map((s) => s.text).join(), 'Салом @ali.\n#Ҳисор, https://x.tj/#no');
    });

    test('email зикр нест', () {
      final segs = linkSegments('mail a@bc.tj');
      expect(segs.where((s) => s.kind == LinkKind.mention), isEmpty);
    });
  });

  test('compactCount', () {
    expect(compactCount(999), '999');
    expect(compactCount(1200), '1.2K');
    expect(compactCount(1000), '1K');
    expect(compactCount(15300), '15K');
    expect(compactCount(2500000), '2.5M');
  });
}
