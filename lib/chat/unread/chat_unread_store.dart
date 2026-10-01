// lib/chat/unread/chat_unread_store.dart
//
// Ҳисоби паёмҳои хонданашуда барои ТАМОМИ барнома — мисли WhatsApp:
//
//  • бейҷи ҳар чат дар inbox (`unreadFor(chatId)` — тағйироти маҳаллӣ);
//  • бейҷи умумӣ дар навбари поён (`total`).
//
// Манбаъҳо:
//  • экрани чат — ҳар бор, ки паёмҳо дар экран дида мешаванд
//    (`markedLocally`), ва ҷавоби сервер (`applyServer`);
//  • сокет: «chat:unread» (дастгоҳи дигари ҳамин корбар хонд) ва
//    «chat:new» (паёми нав — агар ин чат ҳозир кушода набошад);
//  • GET /chat ва GET /chat/unread-count (`setTotal`).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/user_session.dart';

class ChatUnreadStore extends ChangeNotifier {
  ChatUnreadStore._();
  static final ChatUnreadStore instance = ChatUnreadStore._();

  /// Барои тестҳо — нусхаи мустақил.
  @visibleForTesting
  factory ChatUnreadStore.forTest() => ChatUnreadStore._();

  int _total = 0;
  int get total => _total;

  /// chatId → шумораи охирини маълум (аз экрани чат ё сокет).
  final Map<String, int> _overrides = {};
  final Map<String, DateTime> _overrideAt = {};

  /// Чате, ки ҳозир дар экран кушода аст (паёми нав дар он бейҷ намедиҳад).
  String? activeChatId;

  /// Шумораи маҳаллӣ барои чат, агар маълум бошад.
  int? unreadFor(String chatId) => _overrides[chatId];

  /// Тағйироти навтарин аз [since] (барои муқоисаи пойга бо GET /chat).
  bool changedSince(String chatId, DateTime since) {
    final at = _overrideAt[chatId];
    return at != null && at.isAfter(since);
  }

  void setTotal(int? v) {
    if (v == null) return;
    final n = v < 0 ? 0 : v;
    if (n == _total) return;
    _total = n;
    notifyListeners();
  }

  /// Экрани чат [delta] паёмро ҳозир хонд — бейҷҳо фавран кам мешаванд,
  /// бе интизори сервер.
  void markedLocally(String chatId, {required int remaining, int delta = 0}) {
    _overrides[chatId] = remaining < 0 ? 0 : remaining;
    _overrideAt[chatId] = DateTime.now();
    if (delta > 0) _total = (_total - delta).clamp(0, 1 << 30);
    notifyListeners();
  }

  /// Ҷавоби сервер — ҳақиқати охирин.
  void applyServer(String chatId, int unread, int? total) {
    _overrides[chatId] = unread < 0 ? 0 : unread;
    _overrideAt[chatId] = DateTime.now();
    if (total != null) _total = total < 0 ? 0 : total;
    notifyListeners();
  }

  /// Паёми нав омад (сокет). [myId] — то паёми худам ҳисоб нашавад.
  void onIncoming(Map data, String myId) {
    final chatId = data['chatId']?.toString() ?? '';
    final sender = data['sender'];
    final senderId = sender is Map
        ? (sender['_id'] ?? sender['id'])?.toString() ?? ''
        : sender?.toString() ?? '';
    if (chatId.isEmpty || senderId.isEmpty || senderId == myId) return;
    if (chatId == activeChatId) return; // экран худаш хонда мекунад
    final cur = _overrides[chatId];
    if (cur != null) {
      _overrides[chatId] = cur + 1;
      _overrideAt[chatId] = DateTime.now();
    }
    _total++;
    notifyListeners();
  }

  /// Пеш аз GET /chat-и нав: тағйироти кӯҳнаро партоем.
  void forget(String chatId) {
    _overrides.remove(chatId);
    _overrideAt.remove(chatId);
  }

  void reset() {
    _overrides.clear();
    _overrideAt.clear();
    _total = 0;
    activeChatId = null;
    notifyListeners();
  }

  // ── Сокет ва сервер ───────────────────────────────────────────
  bool _wired = false;
  Timer? _refreshDebounce;

  /// Як бор: шунавандаҳои сокет + шумораи аввал аз сервер.
  void wire() {
    if (_wired) return;
    _wired = true;
    final s = SocketService.instance;
    s.on('chat:new', (d) {
      if (d is! Map) return;
      onIncoming(d, UserSession.userId ?? s.userId ?? '');
      // Паёми ба дархост/чати хомӯш сервер ҳисоб намекунад — баъд аз
      // лаҳзае шумораи дақиқро мегирем.
      _refreshSoon();
    });
    s.on('chat:unread', (d) {
      if (d is! Map) return;
      final chatId = d['chatId']?.toString() ?? '';
      if (chatId.isEmpty) return;
      applyServer(chatId, (d['unreadCount'] as num?)?.toInt() ?? 0,
          (d['totalUnread'] as num?)?.toInt());
    });
    refresh();
  }

  void _refreshSoon() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 1500), refresh);
  }

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.get('/chat/unread-count');
      if (res.statusCode >= 400) return;
      final j = jsonDecode(res.body);
      if (j is Map) setTotal((j['totalUnread'] as num?)?.toInt());
    } catch (_) {/* best-effort */}
  }
}
