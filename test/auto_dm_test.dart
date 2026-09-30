import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/create/auto_dm_sheet.dart';

void main() {
  test('parseKeywords splits, trims and dedupes', () {
    expect(AutoDmDraft.parseKeywords(' 1, салом ,салом;нарх\n'),
        ['1', 'салом', 'нарх']);
  });

  test('validate mirrors server rules', () {
    expect(const AutoDmDraft(keywords: ['1'], message: 'x').validate(), isNull);
    expect(const AutoDmDraft(anyWord: true, link: 'https://a.tj').validate(), isNull);
    expect(const AutoDmDraft(keywords: ['1'], link: 'http://a.tj').validate(), isNotNull);
    expect(const AutoDmDraft(keywords: ['1']).validate(), isNotNull);
    expect(const AutoDmDraft(message: 'x').validate(), isNotNull);
  });

  test('json roundtrip', () {
    const d = AutoDmDraft(keywords: ['1'], message: 'm', link: 'https://a.tj', enabled: false);
    final back = AutoDmDraft.fromJson(d.toJson());
    expect(back.keywords, ['1']);
    expect(back.enabled, isFalse);
    expect(back.link, 'https://a.tj');
  });
}
