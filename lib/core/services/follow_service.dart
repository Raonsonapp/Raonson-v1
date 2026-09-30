// lib/core/services/follow_service.dart
// Ҳолати ягонаи «обуна» барои тамоми барнома. Вақте дар ягон ҷо (home,
// reels, search, профил) касеро follow/unfollow мекунӣ, ҳамаи тугмаҳои
// дигар фавран нав мешаванд (мисли Instagram).
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

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

  /// Follow/unfollow мекунад, ҳолатро фавран (optimistic) нав мекунад ва
  /// ба сервер мефиристад. Қимати нави обунаро бармегардонад.
  Future<bool> toggle(String userId, bool currentlyFollowing) async {
    if (_inFlight.contains(userId)) return currentlyFollowing;
    _inFlight.add(userId);
    final next = !currentlyFollowing;
    _set(userId, next); // optimistic
    try {
      // `…Ok` — вагарна рад кардани сервер (масалан маҳдудият ё
      // бастани ҳисоб) хато ҳисоб намешуд ва дар экран «Обуна шуд»
      // мемонд, ҳол он ки дар сервер ҳеҷ чиз нашуда буд.
      if (next) {
        await ApiClient.instance.postOk('/follow/$userId');
      } else {
        await ApiClient.instance.deleteOk('/follow/$userId');
      }
    } catch (_) {
      _set(userId, currentlyFollowing); // баргардонӣ
      return currentlyFollowing;
    } finally {
      _inFlight.remove(userId);
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
    if (states.value.isNotEmpty) states.value = {};
  }
}
