// test/base_url_test.dart
// Суроғаи backend бояд ЯК манбаъ дошта бошад.
//
// Дар дастгоҳ хатои «Failed host lookup:
// mahmadmurodov-raonson.hf.space» пайдо шуд. Санҷиш нишон дод, ки
// худи суроға ДУРУСТ аст:
//
//   • .github/workflows/deploy.yml → repo_id="Mahmadmurodov/raonson"
//     HuggingFace аз он маҳз `mahmadmurodov-raonson.hf.space`
//     месозад;
//   • DNS-и ҷамъиятӣ се A-record бармегардонад.
//
// Яъне он хато дар ТЕЛЕФОН рух дод (DNS/провайдер), на дар код.
//
// Вале дар анбор ДУ нусхаи ин суроға буд:
//   lib/main.dart          → AppConfig (истифода мешавад)
//   lib/core/constants.dart → Constants.baseUrl (ҳеҷ ҷо истифода
//                             намешуд — коди мурда)
//
// Ду манбаъ дер ё зуд аз ҳам дур мешаванд ва он вақт нимаи барнома
// ба суроғаи кӯҳна муроҷиат мекунад. Ин тест инро намегузорад.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<File> dartFiles;

  setUpAll(() {
    dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  });

  test('суроғаи backend танҳо дар ҷойҳои иҷозатдодашуда аст', () {
    // Ҳар файле, ки host-и backend-ро дар худ дорад.
    final holders = <String>[];
    for (final f in dartFiles) {
      if (f.readAsStringSync().contains('hf.space')) {
        holders.add(f.path.replaceAll(r'\', '/'));
      }
    }
    holders.sort();

    expect(
        holders,
        [
          // Ҷои ягонаи ҳақиқӣ: аз ин ҷо ба AppConfig меравад.
          'lib/core/links/deep_links.dart',
          'lib/core/services/network_service.dart',
          'lib/core/services/server_wakeup_service.dart',
          'lib/main.dart',
        ],
        reason: 'нусхаи нави суроғаи backend пайдо шуд. Ҳар нусхаи '
            'иловагӣ дер ё зуд аз ҳам дур мешавад.');
  });

  test('Constants.baseUrl-и мурда барнагаштааст', () {
    expect(File('lib/core/constants.dart').existsSync(), isFalse,
        reason: 'нусхаи дуюми суроға, ки ҳеҷ ҷо истифода намешуд');
  });

  test('ҳамаи нусхаҳо ба ЯК host ишора мекунанд', () {
    final hosts = <String>{};
    final re = RegExp(r'[a-z0-9-]+\.hf\.space');
    for (final f in dartFiles) {
      hosts.addAll(re.allMatches(f.readAsStringSync()).map((m) => m[0]!));
    }
    expect(hosts.length, 1,
        reason: 'host-ҳои гуногун дар як барнома: $hosts');
    expect(hosts.single, 'mahmadmurodov-raonson.hf.space');
  });

  test('суроға бо ҳадафи ҷойгиркунӣ мувофиқ аст', () {
    // HuggingFace аз `Owner/space` суроғаи `owner-space.hf.space`
    // месозад. Агар касе repo_id-ро иваз кунад ва суроғаро дар
    // барнома фаромӯш кунад, барнома ба ҳеҷ ҷо муроҷиат мекунад.
    final deploy = File('.github/workflows/deploy.yml').readAsStringSync();
    final m = RegExp(r'repo_id="([^"]+)"').firstMatch(deploy);
    expect(m, isNotNull, reason: 'repo_id дар deploy.yml ёфт нашуд');

    final expected =
        '${m![1]!.replaceAll('/', '-').toLowerCase()}.hf.space';
    expect(expected, 'mahmadmurodov-raonson.hf.space',
        reason: 'ҳадафи ҷойгиркунӣ ва суроғаи барнома аз ҳам дуранд');
  });
}
