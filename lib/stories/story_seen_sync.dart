// lib/stories/story_seen_sync.dart
//
// ══════════════════════════════════════════════════════════════════
//  Ҳалқаи сторис — ЯК манбаъ барои ҲАМАИ экранҳо.
//
//  Шикояти соҳиб: «сториси ӯро дидам, дар сатри сторис ҳалқа
//  хокистарӣ шуд, вале дар сарлавҳаи пости ӯ дар Home ранга монд».
//
//  Сабаб: ҳар экран ҳалқаро худаш ҳисоб мекард —
//    • сатри сторис: `g.every((s) => s.viewed)` (StoryController);
//    • PostCard ва Reel controls: `user.hasStory` (ҳамеша ранга);
//    • Reels: кэши `static` -и худаш ва дархости ҷудогона;
//    • профил, чат, шарҳҳо, ҷустуҷӯ: умуман ҳалқа надоштанд.
//  Ва сторисе, ки аз сарлавҳаи пост ё Reels кушода мешуд, ба
//  StoryController намерасид — сатри сторис ҳам ранга мемонд.
//
//  Ҳоло ҳамаи онҳо `StorySeenSync.instance.watch(userId)`-ро гӯш
//  мекунанд. Ҳолат аз се ҷо меояд:
//    1. майдонҳои сервер (`hasStory`, `hasUnseenStory`) — `prime`;
//    2. рӯйхати сторисҳо (GET /stories) — `primeStories`, дақиқ, бо id;
//    3. амали худи корбар — `markViewed` (тамошобин), `markNewStory`.
//  Амали маҳаллии навтар аз ҷавоби куҳнаи сервер пахш намешавад
//  (ҳамон қоидаи ContentSync бо `fetchedAt`).
// ══════════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';

import '../models/story_model.dart';
import '../models/user_model.dart';

/// Ҳолати ҳалқа: нест, ранга (надида), хокистарӣ (дида шуд).
enum StoryRing { none, unseen, seen }

class StorySeenSync {
  StorySeenSync._();
  static final StorySeenSync instance = StorySeenSync._();

  /// Барои тест — вақтро идора кардан.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  final Map<String, ValueNotifier<StoryRing>> _rings = {};
  /// userId → id-ҳои сторисҳои фаъоле, ки медонем.
  final Map<String, Set<String>> _storyIds = {};
  /// id-ҳои сторисҳое, ки ин корбар дидааст.
  final Set<String> _viewed = {};
  /// userId → вақти охирин амали маҳаллӣ (дидам / сториси нав).
  final Map<String, DateTime> _localAt = {};
  static const Duration localGrace = Duration(seconds: 10);

  /// Ҳар «дидам» — StoryController онро гӯш мекунад, то сатри сторис
  /// ҳам хокистарӣ шавад, ҳатто агар сторис аз пост кушода шуда бошад.
  final ValueNotifier<String?> lastViewed = ValueNotifier<String?>(null);

  ValueNotifier<StoryRing> _note(String userId) =>
      _rings.putIfAbsent(userId, () => ValueNotifier(StoryRing.none));

  ValueListenable<StoryRing> watch(String userId) => _note(userId);

  StoryRing ringOf(String userId) => _rings[userId]?.value ?? StoryRing.none;

  bool isViewed(String storyId) => _viewed.contains(storyId);

  void _set(String userId, StoryRing r) {
    if (userId.isEmpty) return;
    _note(userId).value = r;
  }

  /// Маълумоти сервер дар бораи як корбар.
  ///
  /// [unseen] `null` — сервер нагуфт: агар ҳалқа аллакай хокистарӣ
  /// бошад, ҳамон мемонад. [fetchedAt] — кай ҷавоб гирифта шуд; ҷавоби
  /// пеш аз амали маҳаллӣ (мас. «дидам») онро бекор намекунад.
  void prime(String userId,
      {required bool hasStory, bool? unseen, DateTime? fetchedAt}) {
    if (userId.isEmpty) return;
    final local = _localAt[userId];
    // Муҳлати хурд: POST /view шояд ҳанӯз дар роҳ бошад ва ҷавоби
    // каме баъдтар ҳоло «надида» гӯяд.
    if (local != null &&
        (fetchedAt == null || fetchedAt.isBefore(local.add(localGrace)))) {
      return;
    }
    if (!hasStory) {
      _set(userId, StoryRing.none);
      return;
    }
    final cur = ringOf(userId);
    if (unseen == null) {
      if (cur == StoryRing.none) _set(userId, StoryRing.unseen);
      return;
    }
    // Ҷавоби НАВТАР аз амали маҳаллӣ: сервер дуруст аст (мас. баъди
    // «дидам» сториси нав гузошта шуд → боз ранга).
    _set(userId, unseen ? StoryRing.unseen : StoryRing.seen);
  }

  /// Аз модели корбар (лента, reels, профил, explore, ҷустуҷӯ…).
  void primeUser(UserModel u, {DateTime? fetchedAt}) => prime(u.id,
      hasStory: u.hasStory, unseen: u.hasUnseenStory, fetchedAt: fetchedAt);

  /// Аз JSON-и хоми корбар (чат, шарҳҳо, ҷустуҷӯ).
  void primeJson(Map? user, {DateTime? fetchedAt}) {
    if (user == null || user['hasStory'] is! bool) return;
    primeUser(UserModel.fromMinJson(Map<String, dynamic>.from(user)),
        fetchedAt: fetchedAt);
  }

  /// Рӯйхати сторисҳо (GET /stories) — манбаи дақиқ: ҳар сторис id дорад.
  ///
  /// [completeFor] — корбароне, ки рӯйхаташон ПУРРА аст (мас.
  /// `/stories?userId=X`): агар он ҷо сторис набошад → ҳалқа нест.
  void primeStories(Iterable<StoryModel> stories,
      {Iterable<String> completeFor = const []}) {
    final byUser = <String, List<StoryModel>>{};
    for (final s in stories) {
      if (s.user.id.isEmpty) continue;
      byUser.putIfAbsent(s.user.id, () => []).add(s);
      if (s.viewed) _viewed.add(s.id);
    }
    for (final uid in completeFor) {
      if (!byUser.containsKey(uid)) {
        _storyIds.remove(uid);
        _set(uid, StoryRing.none);
      }
    }
    byUser.forEach((uid, list) {
      _storyIds[uid] = list.map((s) => s.id).toSet();
      _set(uid, _allKnownViewed(uid) ? StoryRing.seen : StoryRing.unseen);
    });
  }

  bool _allKnownViewed(String userId) {
    final ids = _storyIds[userId];
    return ids != null && ids.isNotEmpty && ids.every(_viewed.contains);
  }

  /// Тамошобин сторисро нишон дод.
  ///
  /// [groupIds] — ҳамаи сторисҳои ҳамон корбар дар тамошобин. Ҳалқа
  /// танҳо вақте хокистарӣ мешавад, ки ҲАМАИ онҳо дида шуданд — мисли
  /// Instagram.
  void markViewed(String userId, String storyId,
      {Iterable<String> groupIds = const []}) {
    if (storyId.isEmpty) return;
    _viewed.add(storyId);
    if (userId.isNotEmpty) {
      final known = _storyIds.putIfAbsent(userId, () => <String>{});
      known.add(storyId);
      known.addAll(groupIds);
      if (_allKnownViewed(userId)) {
        _localAt[userId] = clock();
        _set(userId, StoryRing.seen);
      }
    }
    lastViewed.value = storyId;
  }

  /// Корбар сториси нав гузошт (худам ё дигаре — аз socket).
  void markNewStory(String userId, {String storyId = ''}) {
    if (userId.isEmpty) return;
    if (storyId.isNotEmpty) {
      _storyIds.putIfAbsent(userId, () => <String>{}).add(storyId);
    }
    _localAt[userId] = clock();
    _set(userId, StoryRing.unseen);
  }

  /// Баъди баромадан аз аккаунт.
  void clear() {
    for (final n in _rings.values) {
      n.value = StoryRing.none;
    }
    _storyIds.clear();
    _viewed.clear();
    _localAt.clear();
  }
}
