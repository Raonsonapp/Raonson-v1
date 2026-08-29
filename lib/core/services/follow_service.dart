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

  /// Ҳолатро аз маълумоти сервер ТАНҲО вақте мегузорад, ки ҳанӯз
  /// ҳолате нест. Пештар он ҳар боре менавишт: агар шумо аз профил
  /// обуна мешудед ва баъд рилсеро мебинед, ки пеш аз обуна бор шуда
  /// буд, prime «обуна» -ро ба «не» бармегардонд ва тугма дубора
  /// «Пайравӣ кунед» мешуд. Амали корбар дар давоми сессия бартарӣ дорад.
  void prime(String userId, bool following) {
    if (userId.isEmpty) return;
    if (states.value.containsKey(userId)) return;
    final next = Map<String, bool>.from(states.value);
    next[userId] = following;
    states.value = next;
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
      if (next) {
        await ApiClient.instance.post('/follow/$userId');
      } else {
        await ApiClient.instance.delete('/follow/$userId');
      }
    } catch (_) {
      _set(userId, currentlyFollowing); // баргардонӣ
      return currentlyFollowing;
    } finally {
      _inFlight.remove(userId);
    }
    return next;
  }

  void _set(String userId, bool following) {
    final next = Map<String, bool>.from(states.value);
    next[userId] = following;
    states.value = next;
  }

  /// Ҳангоми иваз кардани аккаунт — override-ҳои корбари куҳнаро тоза
  /// мекунад, то ки тугмаҳои "Обуна" ба ҷои корбари нав рафтор кунанд.
  void clear() {
    if (states.value.isNotEmpty) states.value = {};
  }
}
