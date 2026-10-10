// lib/core/content_sync.dart
// Ҳолати ягонаи «лайк / захира / шарҳ / паҳн / пинҳони лайкҳо / хомӯшии
// шарҳҳо» барои ҳар пост ва reel дар тамоми барнома (мисли FollowService
// барои обуна).
//
// ⚠️ Чаро ин лозим шуд.
//
// Сервер ҳамеша рақами дуруст медиҳад, вале ҳар экран (Home, Reels,
// Explore, Профил) нусхаи ХУДИ рӯйхатро дар хотира нигоҳ медорад. Корбар
// дар Reels лайк мезад — дар Explore ва профил ҳамон рақами куҳна
// мемонд, то навсозии дастӣ. Акнун ҳар амал ба ин ҷо хабар медиҳад ва
// ҳар корт ба ин ҷо гӯш мекунад.
//
// Қоидаи «кӣ ғолиб аст» (содатарин қоидаи дуруст):
//   • `report` — амали ХУДИ корбар (optimistic, ҷавоби сервер ба ҳамон
//     амал, ё баргардонӣ ҳангоми хато). Ҳамеша менависад.
//   • `prime` — маълумоти рӯйхате, ки аз сервер омада буд. Он бо ВАҚТИ
//     гирифташавиаш (`fetchedAt`) меояд ва танҳо вақте менависад, ки
//       1) аз охирин амали корбар барои ҳамин id + [localGrace] навтар
//          бошад — рӯйхате, ки ПЕШ аз амал бор шуда буд, амалро пахш
//          намекунад (grace — барои дархостҳое, ки ҳангоми амал дар роҳ
//          буданд ва сервер ҳанӯз амалро надида буд);
//       2) аз маълумоти сервери аллакай нигоҳдошта кӯҳнатар набошад —
//          вагарна корти рӯйхати куҳна ҳангоми scroll рақами навро
//          бармегардонд.
//     Агар `fetchedAt` маълум набошад (модели дастӣ сохташуда), prime
//     танҳо холигиро пур мекунад — мисли FollowService.prime.
//
// Тамошоҳо (`viewsCount`) қоидаи худро доранд (ниг. [ContentSync.reportViews]):
//   • тамошо дар сервер ҳеҷ гоҳ кам намешавад, пас рақами КАЛОНТАР
//     ҳамеша қабул мешавад (аз ҳар манбаъ, бе grace-и лайк);
//   • рақами ХУРДТАР танҳо аз маълумоте, ки аз охирин рақами маълум
//     НАВТАР гирифта шудааст (масалан ҳисоби бинанда ҳазф шуд);
//   • кэши диск ва рӯйхати кӯҳна ҳеҷ гоҳ рақами навро паст намекунанд.
//
// ⚠️ Чаро: профил reel-ро бо 5 тамошо як бор бор мекард ва плитка
// `r.viewsCount`-и ҳамон моделро нишон медод. Explore ва ҷустуҷӯ ҳар
// дафъа аз нав бор мешуданд ва 8 нишон медоданд — профил то абад 5.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'local_activity.dart';

@immutable
class ContentState {
  final bool? liked;
  final int?  likesCount;
  final bool? saved;
  final int?  commentsCount;
  final int?  sharesCount;
  final bool? hideLikes;
  final bool? commentsOff;
  // Матни пост: баъди таҳрир дар ҳамаи экранҳо фавран нав мешавад
  // (пеш танҳо дар профил, дар лента баъди соатҳо, дар Explore — ҳеҷ).
  final String? caption;
  /// Шумораи тамошо (reel: views_count; пост: COUNT(post_views)).
  final int? viewsCount;

  const ContentState({
    this.liked,
    this.likesCount,
    this.saved,
    this.commentsCount,
    this.sharesCount,
    this.hideLikes,
    this.commentsOff,
    this.caption,
    this.viewsCount,
  });

  /// Майдонҳои маълуми [o] болои ҳамин мегузоранд (null = «номаълум»).
  ContentState mergedWith(ContentState o) => ContentState(
        liked:         o.liked         ?? liked,
        likesCount:    o.likesCount    ?? likesCount,
        saved:         o.saved         ?? saved,
        commentsCount: o.commentsCount ?? commentsCount,
        sharesCount:   o.sharesCount   ?? sharesCount,
        hideLikes:     o.hideLikes     ?? hideLikes,
        commentsOff:   o.commentsOff   ?? commentsOff,
        caption:       o.caption       ?? caption,
        viewsCount:    o.viewsCount    ?? viewsCount,
      );

  @override
  bool operator ==(Object other) =>
      other is ContentState &&
      other.liked == liked &&
      other.likesCount == likesCount &&
      other.saved == saved &&
      other.commentsCount == commentsCount &&
      other.sharesCount == sharesCount &&
      other.hideLikes == hideLikes &&
      other.commentsOff == commentsOff &&
      other.caption == caption &&
      other.viewsCount == viewsCount;

  @override
  int get hashCode => Object.hash(liked, likesCount, saved, commentsCount,
      sharesCount, hideLikes, commentsOff, caption, viewsCount);

  @override
  String toString() => 'ContentState(liked: $liked, likes: $likesCount, '
      'saved: $saved, comments: $commentsCount, shares: $sharesCount, '
      'views: $viewsCount, hideLikes: $hideLikes, commentsOff: $commentsOff)';
}

class ContentSync {
  ContentSync._();
  static final ContentSync instance = ContentSync._();

  /// Калиде, ки дар JSON-и хоми сервер вақти гирифтанро нигоҳ медорад —
  /// то кэши диск (ки баъдтар parse мешавад) «нав» ҳисоб нашавад.
  static const fetchedAtKey = '_fetchedAt';

  /// Дархостҳое, ки ҳангоми амал дар роҳ буданд, метавонанд ҳолати
  /// ПЕШ аз амалро баргардонанд. Дар ин муддат prime амалро пахш намекунад.
  static const localGrace = Duration(seconds: 10);

  /// Барои тестҳо вақтро иваз кардан мумкин аст.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// id → охирин ҳолати маълум. Барои гӯш кардани ҳама.
  final ValueNotifier<Map<String, ContentState>> states =
      ValueNotifier<Map<String, ContentState>>({});

  // Барои гӯш кардани ТАНҲО як id — корт аз ҳар тағйири дигар аз нав
  // кашида намешавад.
  final Map<String, ValueNotifier<ContentState?>> _byId = {};
  final Map<String, DateTime> _localAt  = {};
  final Map<String, DateTime> _serverAt = {};
  // Кай рақами ҷории тамошо маълум шуд (ниг. қоидаи тамошо дар боло).
  final Map<String, DateTime> _viewsAt  = {};

  ContentState? get(String id) => states.value[id];

  /// Ҳолати [fallback] (аз модели худи экран) бо ҳар чизи маълуми ин ҷо.
  ContentState view(String id, ContentState fallback) {
    final s = states.value[id];
    return s == null ? fallback : fallback.mergedWith(s);
  }

  /// Гӯш кардан ба як id.
  ValueListenable<ContentState?> watch(String id) =>
      _byId.putIfAbsent(id, () => ValueNotifier<ContentState?>(get(id)));

  /// Амали корбар (ё ҷавоб/баргардонии он). Ҳамеша менависад.
  void report(String id, {
    bool? liked, int? likesCount, bool? saved, int? commentsCount,
    int? sharesCount, bool? hideLikes, bool? commentsOff, String? caption,
  }) {
    if (id.isEmpty) return;
    _localAt[id] = clock();
    LocalActivity.bump();
    _merge(id, ContentState(
      liked: liked, likesCount: _nonNeg(likesCount), saved: saved,
      commentsCount: _nonNeg(commentsCount), sharesCount: _nonNeg(sharesCount),
      hideLikes: hideLikes, commentsOff: commentsOff, caption: caption,
    ));
  }

  /// Маълумоти сервер аз рӯйхат. Ниг. қоида дар боло.
  void prime(String id, {
    bool? liked, int? likesCount, bool? saved, int? commentsCount,
    int? sharesCount, bool? hideLikes, bool? commentsOff, String? caption,
    int? viewsCount, DateTime? fetchedAt,
  }) {
    if (id.isEmpty) return;
    // Тамошо — қоидаи худ, новобаста аз лайк (ниг. боло).
    _primeViews(id, viewsCount, fetchedAt);
    if (fetchedAt == null) {
      if (states.value.containsKey(id)) return;
    } else {
      final local = _localAt[id];
      if (local != null && !fetchedAt.isAfter(local.add(localGrace))) return;
      final server = _serverAt[id];
      if (server != null && fetchedAt.isBefore(server)) return;
      _serverAt[id] = fetchedAt;
    }
    _merge(id, ContentState(
      liked: liked, likesCount: _nonNeg(likesCount), saved: saved,
      commentsCount: _nonNeg(commentsCount), sharesCount: _nonNeg(sharesCount),
      hideLikes: hideLikes, commentsOff: commentsOff, caption: caption,
    ));
  }

  /// Сервер баъди ҳисоби тамошо рақами ҷориро баргардонд (POST /view,
  /// /watch, /posts/view, /posts/view-batch) ё экрани омор онро нав
  /// гирифт. Ин рақами навтарин аст — дар ҳамаи экранҳо фавран.
  void reportViews(String id, int? views) {
    if (id.isEmpty || views == null || views < 0) return;
    _viewsAt[id] = clock();
    _merge(id, ContentState(viewsCount: views));
  }

  /// Ҷавоби хоми POST /view, /watch ё /posts/view → [reportViews].
  void reportViewsBody(String id, String body) {
    try {
      reportViews(id, viewsFromJson(jsonDecode(body)));
    } catch (_) {/* ҷавоби бе рақам — сервери кӯҳна */}
  }

  /// Рақами тамошо аз ҷавоби сервер (`viewsCount` ё `views`).
  static int? viewsFromJson(Object? body) {
    if (body is! Map) return null;
    final v = body['viewsCount'] ?? body['views'];
    return v is num ? v.toInt() : null;
  }

  void _primeViews(String id, int? views, DateTime? fetchedAt) {
    if (views == null || views < 0) return;
    final cur = states.value[id]?.viewsCount;
    final at  = _viewsAt[id];
    final accept = cur == null ||
        views > cur ||
        // Хурдтар — танҳо аз маълумоти навтар аз рақами ҷорӣ.
        (views < cur && fetchedAt != null && at != null && fetchedAt.isAfter(at));
    if (fetchedAt != null && (at == null || fetchedAt.isAfter(at)) &&
        (accept || views == cur)) {
      _viewsAt[id] = fetchedAt;
    }
    if (!accept || views == cur) return;
    _merge(id, ContentState(viewsCount: views));
  }

  /// Prime аз initState/didUpdateWidget: хабар додани виҷетҳои дигар
  /// МАҲЗ ҳангоми build хатои «markNeedsBuild() called during build»
  /// медиҳад — пас баъди кадри ҷорӣ (microtask) иҷро мешавад.
  static void primeSoon(void Function() prime) => scheduleMicrotask(prime);

  /// Шарҳ илова/ҳазф шуд. [base] — рақами экран, агар ин ҷо ҳанӯз нест.
  void bumpComments(String id, int delta, {int? base}) {
    final cur = get(id)?.commentsCount ?? base;
    if (cur == null) return;
    final next = cur + delta;
    report(id, commentsCount: next < 0 ? 0 : next);
  }

  /// Ҳангоми иваз кардани аккаунт / баромадан — лайк ва захираҳои
  /// корбари куҳна набояд ба корбари нав гузаранд.
  void clear() {
    _localAt.clear();
    _serverAt.clear();
    _viewsAt.clear();
    for (final n in _byId.values) {
      n.value = null;
    }
    if (states.value.isNotEmpty) states.value = {};
  }

  // ── Ёрдамчиҳо барои JSON-и хом ───────────────────────────────

  /// Вақти гирифтанро ба JSON-и сервер менависад (агар ҳанӯз нест).
  static void stamp(Object? json, [DateTime? at]) {
    if (json is Map && json[fetchedAtKey] == null) {
      json[fetchedAtKey] = (at ?? DateTime.now()).millisecondsSinceEpoch;
    }
  }

  /// [stamp] барои ҳар унсури рӯйхат.
  static void stampAll(Object? list, [DateTime? at]) {
    if (list is! List) return;
    final t = at ?? DateTime.now();
    for (final e in list) {
      stamp(e, t);
    }
  }

  static DateTime? fetchedAtOf(Map json) {
    final v = json[fetchedAtKey];
    return v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
  }

  // Сервер барои «лайкҳо пинҳон» -1 мефиристад — ин рақам нест.
  static int? _nonNeg(int? v) => (v == null || v < 0) ? null : v;

  void _merge(String id, ContentState patch) {
    final prev = states.value[id];
    final next = prev == null ? patch : prev.mergedWith(patch);
    if (next == prev) return;
    states.value = Map<String, ContentState>.from(states.value)..[id] = next;
    final n = _byId[id];
    if (n != null) n.value = next;
  }
}
