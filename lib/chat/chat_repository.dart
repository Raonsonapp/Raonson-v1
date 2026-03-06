import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  static String? _myId;
  static final Map<String, UserModel> _users = {};

  Future<String> _myUserId() async {
    if (_myId != null && _myId!.isNotEmpty) return _myId!;
    try {
      final r = await _api.get('/profile/me');
      if (r.statusCode == 200) {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        final u = b['user'] as Map? ?? b;
        _myId = (u['_id'] ?? u['id'])?.toString() ?? '';
      }
    } catch (e) { debugPrint('[Chat] myId: $e'); }
    return _myId ?? '';
  }

  Future<UserModel?> _getUser(String id) async {
    if (id.isEmpty) return null;
    if (_users.containsKey(id)) return _users[id];
    try {
      final r = await _api.get('/users/$id');
      if (r.statusCode == 200) {
        final u = UserModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
        _users[id] = u;
        return u;
      }
    } catch (e) { debugPrint('[Chat] getUser $id: $e'); }
    return null;
  }

  Future<List<MessageModel>> getInboxChats() async {
    final myId = await _myUserId();
    final res = await _api.getRequest(ApiEndpoints.chat);
    if (res.statusCode >= 400) throw Exception('${res.statusCode}');

    final body = jsonDecode(res.body);
    final List raw = body is List ? body : (body['chats'] ?? []);
    final List<MessageModel> out = [];

    for (final e in raw) {
      try {
        final map = e as Map<String, dynamic>;

        // ── NEW backend format: has peer object ──
        if (map['peer'] is Map) {
          final m = MessageModel.fromJson(map);
          if (m.peer.username.isNotEmpty) out.add(m);
          continue;
        }

        // ── OLD backend format: {_id: chatId, lastMessage: {...}} ──
        final chatId = map['_id']?.toString() ?? '';
        if (!chatId.contains('_')) continue;
        final msg = (map['lastMessage'] ?? map) as Map<String, dynamic>;

        final parts  = chatId.split('_');
        final peerId = parts.firstWhere((p) => p != myId && p.isNotEmpty, orElse: () => '');
        if (peerId.isEmpty) continue;

        final peer = await _getUser(peerId);
        if (peer == null) continue;

        final senderStr = msg['sender']?.toString() ?? '';
        final isMine    = myId.isNotEmpty && senderStr == myId;

        DateTime t;
        try { t = DateTime.parse(msg['createdAt'].toString()); }
        catch (_) { t = DateTime.now(); }

        out.add(MessageModel(
          id: msg['_id']?.toString() ?? chatId,
          chatId: chatId,
          peer: peer,
          text: msg['text']?.toString() ?? '',
          createdAt: t,
          isMine: isMine,
        ));
      } catch (err) { debugPrint('[Chat] item: $err'); }
    }
    return out;
  }

  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final myId = await _myUserId();
    final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (cr.statusCode >= 400) throw Exception('chat ${cr.statusCode}');
    final chatId = (jsonDecode(cr.body) as Map)['chatId'] as String;

    final mr = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (mr.statusCode >= 400) throw Exception('messages ${mr.statusCode}');
    final body = jsonDecode(mr.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data.map((e) => MessageModel.fromRoomJson(e as Map<String, dynamic>, myId)).toList();
  }

  Future<MessageModel> sendMessage({required String toUserId, required String text}) async {
    final myId = await _myUserId();
    final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId');
    if (cr.statusCode >= 400) throw Exception('chat');
    final chatId = (jsonDecode(cr.body) as Map)['chatId'] as String;

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': toUserId, 'text': text},
    );
    if (res.statusCode >= 400) throw Exception('send');
    return MessageModel.fromRoomJson(jsonDecode(res.body) as Map<String, dynamic>, myId);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }
}
