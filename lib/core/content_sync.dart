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
import 'dart:async';
import 'package:flutter/foundation.dart';

@immutable
class ContentState {
  final bool? liked;
  final int?  likesCount;
  final bool? saved;
  final int?  commentsCount;
  final int?  sharesCount;
  final bool? hideLikes;
  final bool? commentsOff;

  const ContentState({
    this.liked,
    this.likesCount,
    this.saved,
    this.commentsCount,
    this.sharesCount,
    this.hideLikes,
    this.commentsOff,
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
      other.commentsOff == commentsOff;

  @override
  int get hashCode => Object.hash(liked, likesCount, saved, commentsCount,
      sharesCount, hideLikes, commentsOff);

  @override
  String toString() => 'ContentState(liked: $liked, likes: $likesCount, '
      'saved: $saved, comments: $commentsCount, shares: $sharesCount, '
      'hideLikes: $hideLikes, commentsOff: $commentsOff)';
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
    int? sharesCount, bool? hideLikes, bool? commentsOff,
  }) {
    if (id.isEmpty) return;
    _localAt[id] = clock();
    _merge(id, ContentState(
      liked: liked, likesCount: _nonNeg(likesCount), saved: saved,
      commentsCount: _nonNeg(commentsCount), sharesCount: _nonNeg(sharesCount),
      hideLikes: hideLikes, commentsOff: commentsOff,
    ));
  }

  /// Маълумоти сервер аз рӯйхат. Ниг. қоида дар боло.
  void prime(String id, {
    bool? liked, int? likesCount, bool? saved, int? commentsCount,
    int? sharesCount, bool? hideLikes, bool? commentsOff,
    DateTime? fetchedAt,
  }) {
    if (id.isEmpty) return;
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
      hideLikes: hideLikes, commentsOff: commentsOff,
    ));
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
