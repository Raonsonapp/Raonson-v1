// lib/chat/chat_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/notifications/upload_notifier.dart';
import '../core/storage/offline_cache.dart';
import '../core/storage/token_storage.dart';
import '../create/upload/upload_manager.dart';
import '../models/message_model.dart';
import '../core/moderation/content_policy.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  /// Кэши inbox дар [OfflineCache] — ба корбари воридшуда баста аст ва
  /// «куҳна» намешавад: бе интернет ҳамеша рӯйхати охирин нишон дода
  /// мешавад (пеш баъди 12 соат кэш партофта мешуд → «Паёме нест»).
  static const _inboxName  = 'chat_inbox';
  static const _inboxMax   = 60;
  /// Калиди куҳнаи бе-корбар — танҳо барои тоза кардан.
  static const _legacyInboxKey = 'chat_inbox_cache';

  // Пас аз иваз кардани аккаунт: кэши куҳнаи бе-корбарро тоза мекунем.
  // Кэши нав аз рӯи корбар ҷудост ва нигоҳ дошта мешавад.
  static Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyInboxKey);
      // Кэши кӯҳнаи паёмҳо аз рӯи peerId буд (байни аккаунтҳо омехта
      // мешуд) — калидҳои боқимондаашро пок мекунем. Кэши нав (chat_msgs_v2_)
      // аз рӯи chatId аст ва ба аккаунт вобаста, пас нигоҳ дошта мешавад.
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith('chat_messages_')) await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<String> _myId() async => await TokenStorage.getUserId() ?? '';

  // ── INBOX бо cache ──────────────────────────────────────────
  Future<List<MessageModel>> getInboxChats() async {
    // 1. Cache аввал
    final cached = await _loadInbox();
    if (cached != null && cached.isNotEmpty) {
      _refreshInboxBackground();
      return cached;
    }
    // 2. Network
    return (await fetchInboxFresh())?.chats ?? [];
  }

  /// Танҳо кэши диск (бе шабака) — барои фавран нишон додани inbox.
  Future<List<MessageModel>?> loadCachedInbox() => _loadInbox();

  /// Хатои охирини [fetchInboxFresh] — барои матни фаҳмо дар экран.
  Object? lastInboxError;

  /// Inbox аз шабака (ва кэш нав мешавад). `null` = хатои шабака
  /// (сабаб дар [lastInboxError]).
  ///
  /// ⚠️ Пеш `getInboxChats` кэши то 12-соатаро бармегардонд ва навсозии
  /// фонӣ натиҷаро ба экран намерасонд — бейҷи «2» баъди хондан ҳам
  /// аз кэш бармегашт. Акнун контроллер баъди кэш ҲАМЕША инро мегирад.
  Future<({List<MessageModel> chats, int? totalUnread})?> fetchInboxFresh() async {
    lastInboxError = null;
    try {
      final res = await _api.getRequest(ApiEndpoints.chat);
      if (res.statusCode >= 400) {
        lastInboxError = ApiException(res.statusCode, res.body);
        return null;
      }
      final body = jsonDecode(res.body);
      final List raw = body is List ? body : (body['chats'] ?? []);
      final total = body is Map ? (body['totalUnread'] as num?)?.toInt() : null;
      final out = <MessageModel>[];
      for (final e in raw) {
        try {
          final m = MessageModel.fromJson(e as Map<String, dynamic>);
          if (m.peer.username.isNotEmpty) out.add(m);
        } catch (err) { debugPrint('[Chat] parse: $err'); }
      }
      await OfflineCache.put(_inboxName, raw, maxItems: _inboxMax);
      return (chats: out, totalUnread: total);
    } catch (e) {
      lastInboxError = e;
      return null;
    }
  }

  Future<List<MessageModel>?> _loadInbox() async {
    try {
      final c = await OfflineCache.get(_inboxName);
      if (c == null || c.data is! List) return null;
      final out = <MessageModel>[];
      for (final e in c.data as List) {
        try {
          final m = MessageModel.fromJson(Map<String, dynamic>.from(e as Map));
          if (m.peer.username.isNotEmpty) out.add(m);
        } catch (_) {}
      }
      return out;
    } catch (_) { return null; }
  }

  void _refreshInboxBackground() {
    Future.delayed(const Duration(milliseconds: 800), () async {
      try { await fetchInboxFresh(); } catch (_) {}
    });
  }

  // ── Inbox pagination — саҳифаи навбатиро аз шабака мегирад (бе cache) ──
  Future<List<MessageModel>> fetchInboxPage(int page, {int limit = 30}) async {
    try {
      final res = await _api
          .getRequest('${ApiEndpoints.chat}?page=$page&limit=$limit');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List raw = body is List ? body : (body['chats'] ?? []);
      final out = <MessageModel>[];
      for (final e in raw) {
        try {
          final m = MessageModel.fromJson(e as Map<String, dynamic>);
          if (m.peer.username.isNotEmpty) out.add(m);
        } catch (err) { debugPrint('[Chat] parse: $err'); }
      }
      return out;
    } catch (_) { return []; }
  }

  // ── Messages бо cache ───────────────────────────────────────
  //
  // Кэш аз рӯи chatId (на peerId) нигоҳ дошта мешавад: chatId myId-ро дар
  // худ дорад, пас баъди иваз кардани аккаунт паёмҳои корбари дигар дар
  // чати нав намебароянд.
  static const _msgCacheMax = 60; // танҳо охиринҳо — prefs калон нашавад
  String _msgKey(String chatId) => 'chat_msgs_v2_$chatId';

  /// myId дар давоми умри repository як бор хонда мешавад — SecureStorage
  /// дар Android суст аст ва пеш барои ҳар дархост аз нав хонда мешуд.
  String? _myIdMemo;
  Future<String> _myIdFast() async =>
      _myIdMemo ??= await _myId();

  /// chatId-и 1:1 — айнан мисли `sortedChatID` дар backend
  /// (handlers/helpers.go). Ҳисоби маҳаллӣ як round-trip-и
  /// `/chat/with/:id`-ро пеш аз гирифтани паёмҳо намегузорад.
  static String localChatId(String myId, String peerId) =>
      myId.compareTo(peerId) < 0 ? '${myId}_$peerId' : '${peerId}_$myId';

  /// Паёмҳои кэшшуда (бе шабака) — барои фавран нишон додан.
  Future<List<MessageModel>?> loadCachedMessages(String chatId) async {
    if (chatId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_msgKey(chatId));
      if (raw == null) return null;
      final myId = await _myIdFast();
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final list = payload['data'] as List;
      return list.map((e) =>
          MessageModel.fromRoomJson(e as Map<String,dynamic>, myId)).toList();
    } catch (_) { return null; }
  }

  Future<void> _saveMessagesCache(String chatId, List raw) async {
    if (chatId.isEmpty) return;
    try {
      final data = raw.length > _msgCacheMax
          ? raw.sublist(raw.length - _msgCacheMax)
          : raw;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_msgKey(chatId), jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }));
    } catch (_) {}
  }

  /// Паёми навфиристодаро ба охири кэш илова мекунад — то бозкушоии
  /// навбатӣ онро фавран нишон диҳад (бе интизори шабака).
  Future<void> appendToCache(String chatId, Map<String, dynamic> msg) async {
    if (chatId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_msgKey(chatId));
      final List list = raw == null
          ? []
          : ((jsonDecode(raw) as Map)['data'] as List? ?? []);
      final id = msg['id']?.toString();
      list.removeWhere((e) => e is Map && e['id']?.toString() == id);
      list.add(msg);
      await _saveMessagesCache(chatId, list);
    } catch (_) {}
  }

  // ── chatId-и сӯҳбат бо як корбарро ҳал мекунад ──────────────
  // Маҳаллӣ ҳисоб мешавад (ниг. localChatId); шабака танҳо вақте лозим аст,
  // ки myId ҳанӯз маълум нест.
  Future<String?> resolveChatId(String peerId) async {
    final myId = await _myIdFast();
    if (myId.isNotEmpty && peerId.isNotEmpty) return localChatId(myId, peerId);
    try {
      final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
      if (cr.statusCode >= 400) return null;
      return (jsonDecode(cr.body) as Map)['chatId']?.toString();
    } catch (_) { return null; }
  }

  /// Навтарин паёмҳо аз шабака; `null` = хато (кэшро намезанем),
  /// рӯйхати холӣ = чат воқеан холист. Натиҷа ба кэш навишта мешавад.
  Future<List<MessageModel>?> fetchLatest(String chatId) async {
    try {
      final myId = await _myIdFast();
      final mr = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
      if (mr.statusCode >= 400) return null;
      final body = jsonDecode(mr.body);
      final List data = body is Map ? (body['messages'] ?? []) : body as List;
      // Кэш дар background — UI интизори навиштани диск намешавад.
      _saveMessagesCache(chatId, data);
      return data.map((e) =>
          MessageModel.fromRoomJson(e as Map<String,dynamic>, myId)).toList();
    } catch (_) { return null; }
  }

  // ── Fetch-и мустақим аз шабака — барои auto-refresh ──
  Future<List<MessageModel>> fetchFreshByChatId(String chatId) async =>
      await fetchLatest(chatId) ?? [];

  // ── Паёмҳои кӯҳнатар — саҳифаи навбатӣ (load older) ──────────
  Future<List<MessageModel>> fetchOlderMessages(String chatId, int page,
      {int limit = 30}) async {
    try {
      final myId = await _myIdFast();
      final mr = await _api
          .getRequest('${ApiEndpoints.chat}/$chatId/messages?page=$page&limit=$limit');
      if (mr.statusCode >= 400) return [];
      final body = jsonDecode(mr.body);
      final List data = body is Map ? (body['messages'] ?? []) : body as List;
      return data.map((e) =>
          MessageModel.fromRoomJson(e as Map<String,dynamic>, myId)).toList();
    } catch (_) { return []; }
  }

  // ── Send message бо pending queue (матн ё медиа) ────────────
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
    String? replyToId,
    String? chatId,
    String? mediaUrl,
    String? mediaType, // "image" | "video" | "audio" | "file"
    bool viewOnce = false,
    /// Шиносаи маҳаллӣ барои такрорнашавӣ.
    ///
    /// Агар дархост ба сервер расида бошад, вале ҷавоб гум шуда
    /// бошад, такрор бе ин паёми ДУЮМ месохт.
    String? clientId,
    /// Vanish mode — баъди дидан ва бастани чат нопадид мешавад.
    bool vanish = false,
    /// Вақти фиристодан — паём то ин вақт ба гиранда намерасад.
    DateTime? sendAt,
  }) async {
    final myId = await _myIdFast();
    var cid = chatId;
    if (cid == null || cid.isEmpty) {
      // Маҳаллӣ — бе round-trip-и иловагӣ пеш аз фиристодан.
      cid = await resolveChatId(toUserId);
      if (cid == null || cid.isEmpty) throw Exception('Chat ID not found');
    }

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$cid/messages',
      body: {
        'receiverId': toUserId,
        'text': text,
        if (replyToId != null) 'replyToId': replyToId,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
        if (mediaType != null && mediaType.isNotEmpty) 'type': mediaType,
        if (viewOnce) 'viewOnce': true,
        if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
        if (vanish) 'vanish': true,
        if (sendAt != null) 'sendAt': sendAt.toUtc().toIso8601String(),
      },
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode >= 400) {
      // Мӯҳтаво рад шуд (18+, линки манъшуда) ё ҳисоб маҳдуд аст —
      // такрор кардан бефоида аст: экран инро ба корбар нишон медиҳад.
      final rejection = ContentPolicy.fromResponse(res.statusCode, res.body);
      if (rejection != null) throw rejection;
      throw Exception('Send error');
    }
    final raw = jsonDecode(res.body) as Map<String, dynamic>;
    // Паёми вақтбандишуда ҳанӯз «фиристода» нест — ба кэш намегузорем.
    if (sendAt == null) appendToCache(cid, raw);
    return MessageModel.fromRoomJson(raw, myId);
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final r = await _api.get('/profile/me');
      if (r.statusCode != 200) return null;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      return (b['user'] ?? b) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  /// Паёмҳоро хонда мекунад. [upTo] — танҳо то ҳамин паём (ҳамроҳ),
  /// барои хондани тадриҷӣ. Ҷавоб: (unreadCount, totalUnread) ё null.
  Future<({int unread, int? total})?> markAsRead(String chatId,
      {String? upTo}) async {
    try {
      final res = await _api.postRequest('${ApiEndpoints.chat}/$chatId/read',
          body: {if (upTo != null && upTo.isNotEmpty) 'upTo': upTo});
      if (res.statusCode >= 400) return null;
      final j = jsonDecode(res.body);
      if (j is! Map) return null;
      return (
        unread: (j['unreadCount'] as num?)?.toInt() ?? 0,
        total: (j['totalUnread'] as num?)?.toInt(),
      );
    } catch (_) { return null; }
  }

  // ── Дархостҳои паём: қабул / нест кардан ────────────────────────
  Future<void> clearInboxCache() => OfflineCache.remove(_inboxName);

  Future<bool> acceptRequest(String peerId) async {
    try {
      final r = await _api.postRequest('${ApiEndpoints.chat}/requests/$peerId/accept');
      await clearInboxCache();
      return r.statusCode < 400;
    } catch (_) { return false; }
  }

  Future<bool> deleteRequest(String peerId) async {
    try {
      final r = await _api.postRequest('${ApiEndpoints.chat}/requests/$peerId/delete');
      await clearInboxCache();
      return r.statusCode < 400;
    } catch (_) { return false; }
  }

  /// Хато (шабака ё рад кардани сервер) ПАРТОФТА мешавад. Пеш хато
  /// хомӯшона фурӯ бурда мешуд: паём дар экран «нест шуд», вале дар
  /// сервер мемонд ва баъди кушодани дубораи чат бармегашт.
  Future<void> deleteMessage(String messageId) async {
    await _api.deleteOk('/chat/messages/$messageId');
  }

  /// Ниг. [deleteMessage]: хато партофта мешавад, то экран дурӯғ нагӯяд.
  Future<void> reactToMessage(String messageId, String emoji) async {
    await _api.postOk(
        '/chat/messages/$messageId/react', body: {'emoji': emoji});
  }

  // Медиаро (акс/видео/овоз) ба R2 бор мекунад ва URL-ро бармегардонад.
  //
  // Огоҳиномаи системавӣ («Паёми овозӣ фиристода мешавад… 45%») танҳо
  // вақте пайдо мешавад, ки бор кардан аз ~1 с дароз шавад — паёмҳои
  // хурд дар парда милт намезананд. Ҳамаи чатҳо (1:1 ва гурӯҳ) аз ин
  // ҷо мегузаранд.
  Future<String?> uploadMedia(dynamic file, {UploadKind? kind}) async {
    if (file is! File) return null;
    final notifier = UploadNotifier.instance;
    final nid = notifier.start(kind ?? chatUploadKind(file.path),
        delay: UploadNotifier.chatDelay);
    final report = MonotonicProgress((p) => notifier.progress(nid, p));
    try {
      final url = await UploadManager().uploadFile(file, onProgress: report.call);
      if (url.isEmpty) {
        notifier.failed(nid);
      } else {
        // Паём дар худи чат пайдо мешавад — «Нашр шуд» лозим нест.
        notifier.done(nid, announce: false);
      }
      return url;
    } catch (e) {
      notifier.failed(nid);
      // Расм/видеои 18+ — сервер онро ҳатто нигоҳ намедорад.
      final rejection = ContentPolicy.fromError(e);
      if (rejection != null) throw rejection;
      return null;
    }
  }
}
