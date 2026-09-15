// lib/core/ads/reward_backend.dart
// ════════════════════════════════════════════════════════════════════
//  Хабардиҳии сервер дар бораи рекламаи тамошошуда.
//
//  ⚠️ Yandex server-side verification НАДОРАД: пас аз тамошо ҳеҷ кас
//  ба сервери мо занг намезанад. Ягона хабардиҳанда ҳамин файл аст —
//  яъне худи барнома, ки дар дасти корбар қарор дорад.
//
//  Аз ин рӯ ин ҷо ҳеҷ ҳисоб ва ҳеҷ қарор нест. Барнома ФАҚАТ мегӯяд
//  «сеанси N тамом шуд». Миқдор, зина, баланс ва галочкаро сервер
//  худаш муайян мекунад.
//
//  Барнома ҳеҷ гоҳ намефиристад:
//    • миқдори мукофот
//    • шиносаи корбар (онро сервер аз JWT мегирад)
//    • зина ё баланс
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import '../api/api_client.dart';

/// Ҷавоби сервер ба хабари тамошо.
enum RewardStatus {
  /// Реклама ҳисоб шуд.
  counted,

  /// Ҳамин сеанс аллакай ҳисоб шудааст.
  duplicate,

  /// Сеанс нест, бегона, кӯҳна ё ҷойгиршавӣ нодуруст.
  invalid,

  /// Зуд аз ҳад.
  tooFast,

  /// Ҳадди рӯзона пур шуд. Ин хато НЕСТ.
  dailyCap,

  /// Сервер хусусиятро хомӯш кардааст ё ҷавоб дода наметавонад.
  unavailable,

  /// Ба сервер расидан нашуд. Кӯшиш баъдтар такрор мешавад.
  offline,
}

/// Сарҳади сервер — то тест бе шабака кор кунад.
abstract class RewardBackend {
  /// Сеанси нав мекушояд. null — нашуд.
  Future<String?> openSession(String adUnitId);

  /// Хабар медиҳад, ки сеанс тамом шуд.
  Future<RewardStatus> claim(String sessionId, String adUnitId);
}

/// Иҷрои воқеӣ — тавассути ApiClient.
class ApiRewardBackend implements RewardBackend {
  const ApiRewardBackend();

  @override
  Future<String?> openSession(String adUnitId) async {
    try {
      final res = await ApiClient.instance
          .post('/ads/watch-session', body: {'adUnitId': adUnitId});
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      if (j is! Map) return null;
      final id = j['sessionId'];
      return (id is String && id.isNotEmpty) ? id : null;
    } catch (_) {
      // Шабака нест ё ҷавоб вайрон — реклама нишон дода намешавад.
      return null;
    }
  }

  @override
  Future<RewardStatus> claim(String sessionId, String adUnitId) async {
    try {
      final res = await ApiClient.instance.post('/ads/watched',
          body: {'sessionId': sessionId, 'adUnitId': adUnitId});

      // Сабаби дақиқ аз бадани ҷавоб гирифта мешавад; код танҳо
      // ҳолати умумӣ медиҳад.
      String reason = '';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['reason'] is String) reason = j['reason'] as String;
      } catch (_) {}

      switch (reason) {
        case 'counted':
          return RewardStatus.counted;
        case 'duplicate':
          return RewardStatus.duplicate;
        case 'too_fast':
          return RewardStatus.tooFast;
        case 'daily_cap':
          return RewardStatus.dailyCap;
        case 'invalid':
          return RewardStatus.invalid;
      }

      // Бе `reason` — аз рӯи коди HTTP.
      if (res.statusCode == 200) return RewardStatus.counted;
      if (res.statusCode == 409) return RewardStatus.duplicate;
      if (res.statusCode == 429) return RewardStatus.tooFast;
      if (res.statusCode == 401 || res.statusCode == 403) {
        return RewardStatus.invalid;
      }
      return RewardStatus.unavailable;
    } catch (_) {
      // Шабака қатъ шуд. Сеанс дар сервер ҲАНӮЗ кушода аст, пас
      // кӯшиш баъдтар такрор мешавад (AdsManager).
      return RewardStatus.offline;
    }
  }
}

/// Натиҷаи пурраи як тамошо.
class RewardOutcome {
  /// Оё Yandex мукофотро эълон кард (реклама то охир дида шуд).
  final bool watched;

  /// Ҷавоби сервер.
  final RewardStatus status;

  const RewardOutcome(this.watched, this.status);

  /// Танҳо ин маънои «ҳисоб шуд» дорад — на `watched`.
  bool get counted => status == RewardStatus.counted;

  /// Реклама нишон дода нашуд.
  static const notShown =
      RewardOutcome(false, RewardStatus.unavailable);
}
