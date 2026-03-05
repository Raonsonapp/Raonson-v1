import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  // Cache
  static String? _myId;
  static final Map<String, UserModel> _userCache = {};

  Future<String> _getMyId() async {
    if (_myId != null) return _myId!;
    try {
      final res = await _api.get('/profile/me');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final user = body is Map && body.containsKey('user')
            ? body['user'] as Map<String, dynamic>
            : body as Map<String, dynamic>;
        _myId = (user['_id'] ?? user['id'])?.toString() ?? '';
        return _myId!;
      }
    } catch (e) {
      debugPrint('[Chat] getMyId error: $e');
    }
    return '';
  }

  Future<UserModel?> _fetchUser(String userId) async {
    if (userId.isEmpty) return null;
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final res = await _api.get('/users/$userId');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final userJson = body is Map && body.containsKey('user')
            ? body['user'] as Map<String, dynamic>
            : body as Map<String, dynamic>;
        final user = UserModel.fromJson(userJson);
        _userCache[userId] = user;
        return user;
      }
    } catch (e) {
      debugPrint('[Chat] fetchUser $userId error: $e');
    }
    return null;
  }

  // GET INBOX
  Future<List<MessageModel>> getInboxChats() async {
    final myId = await _getMyId();
    final res = await _api.getRequest(ApiEndpoints.chat);
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Server error ${res.statusCode}');

    final body = jsonDecode(res.body);
    final List raw = body is List ? body : (body['chats'] ?? []);
    if (raw.isEmpty) return [];

    final List<MessageModel> result = [];

    for (final e in raw) {
      try {
        final map = e as Map<String, dynamic>;

        // NEW backend: has peer object directly
        if (map['peer'] is Map) {
          result.add(MessageModel.fromJson(map));
          continue;
        }

        // OLD backend: {_id: chatId, lastMessage: {sender, receiver, text, createdAt}}
        final chatId = map['_id']?.toString() ?? '';
        final msgRaw = map['lastMessage'];
        final msg = msgRaw is Map<String, dynamic> ? msgRaw : map;
        if (chatId.isEmpty) continue;

        // Get peer ID from chatId = "id1_id2"
        final parts = chatId.split('_');
        final peerId = parts.firstWhere(
          (p) => p.isNotEmpty && p != myId,
          orElse: () => '',
        );
        if (peerId.isEmpty) continue;

        final peer = await _fetchUser(peerId);
        if (peer == null) continue;

        final senderStr = msg['sender']?.toString() ?? '';
        final isMine = myId.isNotEmpty && senderStr.endsWith(myId) || senderStr == myId;

        DateTime createdAt;
        try { createdAt = DateTime.parse(msg['createdAt'].toString()); }
        catch (_) { createdAt = DateTime.now(); }

        result.add(MessageModel(
          id: msg['_id']?.toString() ?? '',
          chatId: chatId,
          peer: peer,
          text: msg['text']?.toString() ?? '',
          createdAt: createdAt,
          isMine: isMine,
        ));
      } catch (err) {
        debugPrint('[Chat] inbox item error: $err');
      }
    }

    return result;
  }

  // GET MESSAGES IN ROOM
  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final myId = await _getMyId();
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final msgRes = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (msgRes.statusCode >= 400) throw Exception('Failed to load messages');
    final body = jsonDecode(msgRes.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data
        .map((e) => MessageModel.fromRoomJson(e as Map<String, dynamic>, myId))
        .toList();
  }

  // SEND MESSAGE
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
  }) async {
    final myId = await _getMyId();
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': toUserId, 'text': text},
    );
    if (res.statusCode >= 400) throw Exception('Send failed');
    return MessageModel.fromRoomJson(
        jsonDecode(res.body) as Map<String, dynamic>, myId);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }
}
