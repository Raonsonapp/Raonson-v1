// lib/chat/room/read_tracker.dart
//
// «Дида шуд → хонда шуд» — мисли WhatsApp/Instagram.
//
// Паём танҳо вақте хонда ҳисоб мешавад, ки воқеан дар экран пайдо
// шуд. 10 паёми нав, 4-тоаш дида мешавад → бейҷ 6; то поён scroll →
// 0. Ин мантиқ аз Flutter ҷудо аст, то бо unit-тест санҷида шавад.

/// Маълумоти кофӣ дар бораи як паём.
class ReadItem {
  final String id;
  /// Паёми ҳамсӯҳбат (на худам).
  final bool incoming;
  /// Ман онро аллакай хондаам.
  final bool read;
  const ReadItem({required this.id, required this.incoming, required this.read});

  bool get unread => incoming && !read;
}

/// Натиҷаи як қадами «хонда кардан».
class ReadMark {
  /// Охирин (навтарин) паёми дидашуда — ба сервер ҳамчун `upTo`.
  final String upToId;
  /// Индекси он дар рӯйхат.
  final int upToIndex;
  /// Ҳамин қадар паём ҳоло хонда шуд.
  final int newlyRead;
  /// Ҳамин қадар паёми хонданашуда боқӣ монд (дар рӯйхати боршуда).
  final int remaining;
  const ReadMark({
    required this.upToId,
    required this.upToIndex,
    required this.newlyRead,
    required this.remaining,
  });
}

class ReadTracker {
  final Set<String> _visible = {};

  /// Паёмҳое, ки ҳозир дар экран ҳастанд.
  Set<String> get visible => Set.unmodifiable(_visible);

  void setVisible(String id, bool isVisible) {
    if (isVisible) {
      _visible.add(id);
    } else {
      _visible.remove(id);
    }
  }

  void clear() => _visible.clear();

  /// Шумораи паёмҳои хонданашуда дар [items].
  static int unreadCount(List<ReadItem> items) =>
      items.where((m) => m.unread).length;

  /// [items] — аз кӯҳна ба нав. [visible] — id-ҳои дар экран.
  ///
  /// Навтарин паёми хонданашудаи ҳамсӯҳбатро, ки дар экран аст, меёбад:
  /// он ва ҳамаи паёмҳои ҳамсӯҳбати пеш аз он хонда мешаванд (паёмҳои
  /// болотар аллакай аз экран гузаштаанд — мисли WhatsApp). Агар ҳеҷ
  /// паёми нави дидашуда набошад — `null`.
  static ReadMark? compute(List<ReadItem> items, Set<String> visible) {
    var upTo = -1;
    for (var i = items.length - 1; i >= 0; i--) {
      final m = items[i];
      if (m.unread && visible.contains(m.id)) {
        upTo = i;
        break;
      }
    }
    if (upTo < 0) return null;
    var newly = 0;
    var remaining = 0;
    for (var i = 0; i < items.length; i++) {
      if (!items[i].unread) continue;
      if (i <= upTo) {
        newly++;
      } else {
        remaining++;
      }
    }
    return ReadMark(
      upToId: items[upTo].id,
      upToIndex: upTo,
      newlyRead: newly,
      remaining: remaining,
    );
  }

  /// Барои ҳолати ҷорӣ (бо [visible]-и худи tracker).
  ReadMark? next(List<ReadItem> items) => compute(items, _visible);

  /// Индекси аввалин паёми хонданашуда (барои кушодани чат дар он ҷо,
  /// мисли WhatsApp) ё -1.
  static int firstUnreadIndex(List<ReadItem> items) =>
      items.indexWhere((m) => m.unread);
}
