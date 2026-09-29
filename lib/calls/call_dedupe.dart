// lib/calls/call_dedupe.dart
// ════════════════════════════════════════════════════════════════════
//  Як занг — як экран.
//
//  Сервер акнун push-и зангро ҲАМЕША мефиристад (на танҳо ба офлайн),
//  ва сокет ҳам `call:incoming` медиҳад. Бе ин санҷиш барномаи кушода
//  зангро ду бор нишон медод, ё — бадтар — баъди «Рад» push-и дертар
//  расида зангро аз нав садо медод.
//
//  Қоида:
//    • сокет фаврӣ ва боэътимод аст — ҳамеша нишон медиҳад, магар
//      ҳамин шахс ҳоло занг зада истода бошад;
//    • push — танҳо агар ҳамин шахс на ҳоло занг мезанад ва на
//      чанд сония пеш занги ӯ тамом шуд (push метавонад аз сокет дертар
//      расад).
// ════════════════════════════════════════════════════════════════════

enum CallSource { socket, push }

class CallDedupe {
  CallDedupe({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// Занг ин қадар «фаъол» ҳисоб мешавад, агар тамом нашуда бошад.
  static const ringWindow = Duration(seconds: 60);

  /// Баъди тамом шудан push-и ҳамон шахс ин қадар партофта мешавад.
  static const tombstone = Duration(seconds: 15);

  final Map<String, DateTime> _active = {};
  final Map<String, DateTime> _finished = {};

  /// true — зангро нишон деҳ (ва сабт мешавад); false — такрорист.
  bool shouldShow(String callerId, CallSource source) {
    if (callerId.isEmpty) return false;
    final now = _now();
    _purge(now);
    if (_active.containsKey(callerId)) return false;
    if (source == CallSource.push && _finished.containsKey(callerId)) {
      return false;
    }
    _active[callerId] = now;
    _finished.remove(callerId);
    return true;
  }

  /// Занг тамом шуд (қабул, рад, қатъ, вақт гузашт).
  void finish(String callerId) {
    if (callerId.isEmpty) return;
    _active.remove(callerId);
    _finished[callerId] = _now();
  }

  bool isActive(String callerId) {
    _purge(_now());
    return _active.containsKey(callerId);
  }

  void _purge(DateTime now) {
    _active.removeWhere((_, t) => now.difference(t) > ringWindow);
    _finished.removeWhere((_, t) => now.difference(t) > tombstone);
  }
}
