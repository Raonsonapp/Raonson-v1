// lib/chat/chat_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/token_storage.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  static const _inboxKey   = 'chat_inbox_cache';
  static const _cacheTTL   = Duration(hours: 12);

  Future<String> _myId() async => await TokenStorage.getUserId() ?? '';

  // ── INBOX бо cache ──────────────────────────────────────────
  Future<List<MessageModel>> getInboxChats() async {
    // 1. Cache аввал
    final cached = await _loadInbox();
    if (cached != null) {
      _refreshInboxBackground();
      return cached;
    }
    // 2. Network
    return _fetchInbox();
  }

  Future<List<MessageModel>?> _loadInbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_inboxKey);
      if (raw == null) return null;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (payload['time'] as int);
      if (age > _cacheTTL.inMilliseconds) return null;
      final list = payload['data'] as List;
      return list.map((e) => MessageModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return null; }
  }

  Future<List<MessageModel>> _fetchInbox() async {
    try {
      final res = await _api.getRequest(ApiEndpoints.chat)
          .timeout(const Duration(seconds: 8));
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
      // Кэшга сақла
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_inboxKey, jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'data': raw,
      }));
      return out;
    } catch (_) { return []; }
  }

  void _refreshInboxBackground() {
    Future.delayed(const Duration(milliseconds: 800), () async {
      try { await _fetchInbox(); } catch (_) {}
    });
  }

  // ── Messages бо cache ───────────────────────────────────────
  String _msgKey(String peerId) => 'chat_messages_$peerId';

  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final cacheKey = _msgKey(peerId);

    // Cache аввал
    final cached = await _loadMessages(cacheKey);
    if (cached != null) {
      _refreshMessagesBackground(peerId, cacheKey);
      return cached;
    }
    return _fetchMessages(peerId, cacheKey);
  }

  Future<List<MessageModel>?> _loadMessages(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final myId = await _myId();
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final list = payload['data'] as List;
      return list.map((e) =>
          MessageModel.fromRoomJson(e as Map<String,dynamic>, myId)).toList();
    } catch (_) { return null; }
  }

  Future<List<MessageModel>> _fetchMessages(String peerId, String cacheKey) async {
    try {
      final myId = await _myId();
      final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId')
          .timeout(const Duration(seconds: 8));
      if (cr.statusCode >= 400) return [];
      final chatId = (jsonDecode(cr.body) as Map)['chatId'] as String;

      final mr = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages')
          .timeout(const Duration(seconds: 8));
      if (mr.statusCode >= 400) return [];
      final body = jsonDecode(mr.body);
      final List data = body is Map ? (body['messages'] ?? []) : body as List;

      // Кэшга сақла
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      }));

      return data.map((e) =>
          MessageModel.fromRoomJson(e as Map<String,dynamic>, myId)).toList();
    } catch (_) { return []; }
  }

  void _refreshMessagesBackground(String peerId, String cacheKey) {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try { await _fetchMessages(peerId, cacheKey); } catch (_) {}
    });
  }

  // ── chatId-и сӯҳбат бо як корбарро ҳал мекунад ──────────────
  Future<String?> resolveChatId(String peerId) async {
    try {
      final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId')
          .timeout(const Duration(seconds: 8));
      if (cr.statusCode >= 400) return null;
      return (jsonDecode(cr.body) as Map)['chatId'] as String?;
    } catch (_) { return null; }
  }

  // ── Fetch-и мустақим аз шабака (бе cache) — барои auto-refresh ──
  Future<List<MessageModel>> fetchFreshByChatId(String chatId) async {
    try {
      final myId = await _myId();
      final mr = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages')
          .timeout(const Duration(seconds: 8));
      if (mr.statusCode >= 400) return [];
      final body = jsonDecode(mr.body);
      final List data = body is Map ? (body['messages'] ?? []) : body as List;
      return data.map((e) =>
          MessageModel.fromRoomJson(e as Map<String,dynamic>, myId)).toList();
    } catch (_) { return []; }
  }

  // ── Send message бо pending queue ──────────────────────────
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
    String? replyToId,
    String? chatId,
  }) async {
    final myId = await _myId();
    var cid = chatId;
    if (cid == null || cid.isEmpty) {
      final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId')
          .timeout(const Duration(seconds: 8));
      if (cr.statusCode >= 400) throw Exception('Chat error');
      cid = (jsonDecode(cr.body) as Map)['chatId'] as String;
    }

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$cid/messages',
      body: {'receiverId': toUserId, 'text': text,
             if (replyToId != null) 'replyToId': replyToId},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode >= 400) throw Exception('Send error');
    return MessageModel.fromRoomJson(
        jsonDecode(res.body) as Map<String, dynamic>, myId);
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final r = await _api.get('/profile/me').timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      return (b['user'] ?? b) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  Future<void> markAsRead(String chatId) async {
    try { await _api.postRequest('${ApiEndpoints.chat}/$chatId/read'); } catch (_) {}
  }

  Future<List<MessageModel>> getMessagesWithUserEx(String peerId) =>
      getMessagesWithUser(peerId);

  Future<void> deleteMessage(String messageId) async {
    try { await _api.deleteRequest('/chat/messages/$messageId'); } catch (_) {}
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      await _api.postRequest(
          '/chat/messages/$messageId/react', body: {'emoji': emoji});
    } catch (_) {}
  }

  Future<String?> uploadMedia(dynamic file) async => null;
}
