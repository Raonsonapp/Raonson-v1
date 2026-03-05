import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../core/services/user_session.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;
  String get _myId => UserSession.userId ?? '';

  // Cache peer user info to avoid refetching
  static final Map<String, UserModel> _userCache = {};

  Future<UserModel?> _fetchUser(String userId) async {
    if (userId.isEmpty) return null;
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final res = await _api.getRequest('/users/$userId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data is Map<String, dynamic> ? data : data['user'] as Map<String, dynamic>);
        _userCache[userId] = user;
        return user;
      }
    } catch (e) {
      debugPrint('[Chat] fetchUser error: $e');
    }
    return null;
  }

  // GET INBOX — works with old backend format
  Future<List<MessageModel>> getInboxChats() async {
    final res = await _api.getRequest(ApiEndpoints.chat);
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Server error');

    final body = jsonDecode(res.body);

    // NEW backend format: [{_id, peer:{...}, isMine, text, createdAt}]
    // OLD backend format: [{_id: chatId, lastMessage: {sender, receiver, text, ...}}]
    final List raw = body is List ? body : (body['chats'] ?? []);
    if (raw.isEmpty) return [];

    final List<MessageModel> result = [];

    for (final e in raw) {
      final map = e as Map<String, dynamic>;

      // --- NEW format: has peer object ---
      if (map['peer'] is Map) {
        try {
          result.add(MessageModel.fromJson(map));
        } catch (err) {
          debugPrint('[Chat] inbox parse error: $err');
        }
        continue;
      }

      // --- OLD format: {_id: chatId, lastMessage: {...}} ---
      final chatId = map['_id']?.toString() ?? '';
      final msg = map['lastMessage'] as Map<String, dynamic>?;
      if (chatId.isEmpty || msg == null) continue;

      // Extract peer ID from chatId = "smallId_largeId"
      final parts = chatId.split('_');
      final peerId = parts.firstWhere(
        (p) => p.isNotEmpty && p != _myId,
        orElse: () => '',
      );
      if (peerId.isEmpty) continue;

      // Fetch peer user info
      final peer = await _fetchUser(peerId);
      if (peer == null) continue;

      // Determine isMine
      final senderStr = msg['sender']?.toString() ?? '';
      final isMine = _myId.isNotEmpty && senderStr == _myId;

      DateTime createdAt;
      try {
        createdAt = DateTime.parse(msg['createdAt'].toString());
      } catch (_) {
        createdAt = DateTime.now();
      }

      result.add(MessageModel(
        id: msg['_id']?.toString() ?? '',
        chatId: chatId,
        peer: peer,
        text: msg['text']?.toString() ?? '',
        createdAt: createdAt,
        isMine: isMine,
      ));
    }

    return result;
  }

  // GET MESSAGES IN CHAT ROOM
  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final msgRes = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (msgRes.statusCode >= 400) throw Exception('Failed to load messages');
    final body = jsonDecode(msgRes.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data
        .map((e) => MessageModel.fromRoomJson(e as Map<String, dynamic>, _myId))
        .toList();
  }

  // SEND MESSAGE
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
  }) async {
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': toUserId, 'text': text},
    );
    if (res.statusCode >= 400) throw Exception('Send failed');
    return MessageModel.fromRoomJson(
        jsonDecode(res.body) as Map<String, dynamic>, _myId);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }
}
