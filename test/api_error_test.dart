import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/api/api_client.dart';

// «Тугма зер мешавад, гӯё шуд — вале нашудааст».
//
// ═══════════════════════════════════════════════════════════════════
//  Сабаби решагӣ ЯК сатр буд:
//
//    Future<http.Response> post(...) => _withRetry(...);
//
//  `post` ҳангоми 400, 401, 403, 429 ё 500 хато НАМЕПАРТОЯД — вай
//  `Response` бармегардонад. Пас ин нақш, ки дар барнома даҳҳо ҷо
//  такрор мешуд, ҳеҷ гоҳ кор намекард:
//
//    _set(userId, true);                      // «Обуна шуд»
//    try {
//      await ApiClient.instance.post('/follow/$id');
//    } catch (_) {
//      _set(userId, false);                   // ← ҳеҷ гоҳ
//    }
//
//  Корбар мебинад «Обуна шуд». Баъди навсозӣ обуна нест. Ҳамин тавр
//  бо 2FA, шикоят, ҷавоб ба стори, тағйири шарҳ, баромадан аз гурӯҳ.
//
//  Ҳалли он: усулҳои `…Ok`, ки хатои серверро мепартоянд.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('ApiException', () {
    test('матни серверро мехонад', () {
      const e = ApiException(409, '{"message":"Ин почта банд аст"}');
      expect(e.message, 'Ин почта банд аст');
      expect(e.status, 409);
    });

    test('ҷавоби на-JSON барномаро намешиканад', () {
      const e = ApiException(502, '<html>Bad Gateway</html>');
      expect(e.message, isNull);
      expect(e.toString(), contains('502'));
    });

    test('матни холӣ null аст, на сатри холӣ', () {
      // Вагарна дар экран сатри холӣ ба ҷои хабари фаҳмо менамуд.
      expect(const ApiException(400, '{"message":""}').message, isNull);
      expect(const ApiException(400, '{}').message, isNull);
    });
  });

  group('амалҳои муҳим ҷавоби серверро месанҷанд', () {
    // Ҳар сатри ин ҷадвал як камбудии воқеӣ буд.
    const sites = <String, List<String>>{
      'lib/core/services/follow_service.dart': [
        "postOk('/follow/", "deleteOk('/follow/",
      ],
      'lib/friends/friends_screen.dart': [
        "postOk('/follow/request/", "postOk('/follow/",
      ],
      'lib/settings/settings_screen.dart': [
        "putOk('/profile/", "postOk('/users/",
      ],
      'lib/feed/comments/comments_screen.dart': ["putOk('/comments/"],
      'lib/stories/story_group_viewer.dart': ["postOk('/stories/"],
      'lib/profile/profile_screen.dart': ["postOk('/users/"],
      'lib/chat/group/group_repository.dart': [
        "postOk('/groups/", "deleteOk('/groups/", 'Future<bool> leave',
      ],
    };

    sites.forEach((file, needles) {
      test(file.split('/').last, () {
        final src = _read(file);
        for (final n in needles) {
          expect(src, contains(n),
              reason: 'хатои сервер нодида мемонад — '
                  'дар экран «шуд» менамояд, дар сервер не');
        }
      });
    });
  });

  group('гурӯҳ: экран ба нокомӣ вокуниш нишон медиҳад', () {
    late String src;
    setUpAll(() =>
        src = _read('lib/chat/group/group_info_screen.dart'));

    test('аъзо танҳо баъди тасдиқи сервер нест мешавад', () {
      expect(src, contains('final ok = await _repo.removeMember'));
      expect(src, contains('if (!ok)'));
    });

    test('баромадан аз гурӯҳ ҳангоми хато экранро намепӯшад', () {
      // Пеш `Navigator.popUntil` ҳамеша иҷро мешуд: корбар гумон
      // мекард, ки баромад, вале дар гурӯҳ мемонд.
      expect(src, contains('if (!await _repo.leave(_gid))'));
    });
  });
}
