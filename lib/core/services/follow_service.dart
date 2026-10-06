// lib/core/services/follow_service.dart
// Ҳолати ягонаи «обуна» барои тамоми барнома. Вақте дар ягон ҷо (home,
// reels, search, профил) касеро follow/unfollow мекунӣ, ҳамаи тугмаҳои
// дигар фавран нав мешаванд (мисли Instagram).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

/// Ҷавоби POST /follow/:id: `{"requested": true}` — ҳисоби пӯшида,
/// дархост фиристода шуд, обуна ҳанӯз нест.
bool isFollowRequested(String body) {
  try {
    final j = jsonDecode(body);
    return j is Map && j['requested'] == true;
  } catch (_) {
    return false;
  }
}

/// Манбаи обуна: корти пост, рилс, Explore ё шарҳҳои ҳамон пост.
///
/// Сервер онро танҳо вақте қабул мекунад, ки пост/рилс аз они ҳамон
/// касе бошад, ки ба ӯ обуна мешаванд.
class FollowSource {
  final String kind; // 'post' | 'reel'
  final String id;
  const FollowSource._(this.kind, this.id);
  const FollowSource.post(String id) : this._('post', id);
  const FollowSource.reel(String id) : this._('reel', id);

  Map<String, dynamic>? toJson() =>
      id.isEmpty ? null : {'sourceKind': kind, 'sourceId': id};
}

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();

  /// userId → оё ман пайравӣ мекунам. Танҳо барои касоне, ки ҳолаташон
  /// маълум аст (override-и маҳаллӣ нисбати маълумоти сервер).
  final ValueNotifier<Map<String, bool>> states =
      ValueNotifier<Map<String, bool>>({});

  /// Ҳолати ҷории обунаро бармегардонад: override-и глобалӣ ё қимати default.
  bool resolve(String userId, bool fallback) {
    return states.value[userId] ?? fallback;
  }

  /// Кай ҳолати ҳар корбар муқаррар шуд. Набудан = «вақт номаълум»
  /// (заифтарин): ҳар маълумоти сервер бо `fetchedAt` онро иваз мекунад.
  final Map<String, DateTime> _at = {};

  /// Ҳолатро аз маълумоти сервер мегузорад.
  ///
  /// Бе [fetchedAt] — ТАНҲО вақте ҳанӯз ҳолате нест (рафтори куҳна):
  /// рилсе, ки пеш аз обуна бор шуда буд, амали навро барнагардонад.
  ///
  /// Бо [fetchedAt] — маълумоти сервер, ки БАЪД аз ҳолати мавҷуда гирифта
  /// шуд, ғолиб аст. ⚠️ Пеш баъди бозкушоии барнома Reels аз кэши диск
  /// (бо isFollowing-и куҳна) бор мешуд, аввал prime мекард ва ҷавоби
  /// нави сервер дигар ҳеҷ гоҳ ба ҳисоб намерафт — «Пайравӣ кунед»
  /// дубора пайдо мешуд. Ҳоло нави сервер ҳамеша аз кэши куҳна бартар аст.
  void prime(String userId, bool following, {DateTime? fetchedAt}) {
    if (userId.isEmpty) return;
    if (states.value.containsKey(userId)) {
      if (fetchedAt == null || _inFlight.contains(userId)) return;
      final at = _at[userId];
      if (at != null && !fetchedAt.isAfter(at)) return;
      _at[userId] = fetchedAt;
      if (states.value[userId] == following) return;
    } else if (fetchedAt != null) {
      _at[userId] = fetchedAt;
    }
    final next = Map<String, bool>.from(states.value);
    next[userId] = following;
    states.value = next;
  }

  /// Амали корбар, ки аз ҷои дигар (масалан контроллери профил) ба
  /// сервер рафт — ҲАМЕША менависад. `prime` ин ҷо кор намекард: агар
  /// ҳолат аллакай буд, unfollow-и профил дар reels «обуна» мемонд.
  void report(String userId, bool following) {
    if (userId.isEmpty) return;
    if (states.value[userId] == following) {
      _at[userId] = DateTime.now();
      return;
    }
    _set(userId, following);
  }

  final Set<String> _inFlight = {};

  /// Ба ҳисобҳои пӯшида — дархости обуна фиристода шуд (ҳанӯз обуна нест).
  final Set<String> _requested = {};

  /// Оё ба ин ҳисоби пӯшида дархости обуна фиристодаам?
  bool isRequested(String userId) => _requested.contains(userId);

  /// Ҳолати «дархост»-ро аз маълумоти сервер (followRequestSent) мегирад.
  void primeRequested(String userId, bool requested) {
    if (userId.isEmpty || _inFlight.contains(userId)) return;
    if (requested == _requested.contains(userId)) return;
    requested ? _requested.add(userId) : _requested.remove(userId);
    states.value = Map<String, bool>.from(states.value);
  }

  /// Follow/unfollow мекунад, ҳолатро фавран (optimistic) нав мекунад ва
  /// ба сервер мефиристад. Қимати нави обунаро бармегардонад.
  ///
  /// ⚠️ Ҳисоби ПӮШИДА: сервер `{"requested": true}` медиҳад — обуна ҳанӯз
  /// нест. Пеш тугма «Пайравӣ шуд» мешуд ва ҳамин тавр мемонд, гӯё
  /// корбар аллакай обуна бошад. Акнун «Дархост» нишон дода мешавад ва
  /// пахши дубора дархостро бекор мекунад (мисли Instagram).
  ///
  /// [source] — аз куҷо обуна шуд (пост ё Reel), барои омори соҳиб
  /// «Обуначиён аз ин пост». Танҳо ҳангоми обуна фиристода мешавад.
  Future<bool> toggle(String userId, bool currentlyFollowing,
      {FollowSource? source}) async {
    if (_inFlight.contains(userId)) return currentlyFollowing;
    final cancelRequest = !currentlyFollowing && _requested.contains(userId);
    _inFlight.add(userId);
    final next = !currentlyFollowing && !cancelRequest;
    if (cancelRequest) _requested.remove(userId);
    _set(userId, next); // optimistic
    var requested = false;
    try {
      // `…Ok` — вагарна рад кардани сервер (масалан маҳдудият ё
      // бастани ҳисоб) хато ҳисоб намешуд ва дар экран «Обуна шуд»
      // мемонд, ҳол он ки дар сервер ҳеҷ чиз нашуда буд.
      if (next) {
        final res = await ApiClient.instance
            .postOk('/follow/$userId', body: source?.toJson());
        requested = isFollowRequested(res.body);
      } else {
        await ApiClient.instance.deleteOk('/follow/$userId');
      }
    } catch (_) {
      if (cancelRequest) _requested.add(userId);
      _set(userId, currentlyFollowing); // баргардонӣ
      return currentlyFollowing;
    } finally {
      _inFlight.remove(userId);
    }
    if (requested) {
      _requested.add(userId);
      _set(userId, false);
      return false;
    }
    // Вақти ТАМОМ шудани амал: маълумоте, ки пеш аз ин гирифта шуда
    // буд (ҳанӯз бе обуна), онро барнагардонад.
    _at[userId] = DateTime.now();
    return next;
  }

  void _set(String userId, bool following) {
    _at[userId] = DateTime.now();
    final next = Map<String, bool>.from(states.value);
    next[userId] = following;
    states.value = next;
  }

  /// Ҳангоми иваз кардани аккаунт — override-ҳои корбари куҳнаро тоза
  /// мекунад, то ки тугмаҳои "Обуна" ба ҷои корбари нав рафтор кунанд.
  void clear() {
    _at.clear();
    _requested.clear();
    if (states.value.isNotEmpty) states.value = {};
  }
}
