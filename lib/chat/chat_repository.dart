import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  static String? _myId;
  static final Map<String, UserModel> _userCache = {};

  Future<String> _getMyId() async {
    if (_myId != null && _myId!.isNotEmpty) return _myId!;
    try {
      final res = await _api.get('/profile/me');
      debugPrint('[Chat] profile/me status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user = body.containsKey('user')
            ? body['user'] as Map<String, dynamic>
            : body;
        _myId = (user['_id'] ?? user['id'])?.toString() ?? '';
        debugPrint('[Chat] myId = $_myId');
        return _myId!;
      }
    } catch (e) {
      debugPrint('[Chat] _getMyId error: $e');
    }
    return '';
  }

  Future<UserModel?> _fetchUser(String userId) async {
    if (userId.isEmpty) return null;
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final res = await _api.get('/users/$userId');
      debugPrint('[Chat] /users/$userId status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final userJson = body.containsKey('user')
            ? body['user'] as Map<String, dynamic>
            : body;
        final user = UserModel.fromJson(userJson);
        _userCache[userId] = user;
        return user;
      }
    } catch (e) {
      debugPrint('[Chat] _fetchUser $userId error: $e');
    }
    return null;
  }

  Future<List<MessageModel>> getInboxChats() async {
    final myId = await _getMyId();
    debugPrint('[Chat] getInboxChats myId=$myId');

    final res = await _api.getRequest(ApiEndpoints.chat);
    debugPrint('[Chat] GET /chat status: ${res.statusCode}');
    debugPrint('[Chat] GET /chat body: ${res.body}');

    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Server error ${res.statusCode}: ${res.body}');

    final body = jsonDecode(res.body);
    final List raw = body is List ? body : (body['chats'] ?? []);
    debugPrint('[Chat] raw items: ${raw.length}');
    if (raw.isEmpty) return [];

    final List<MessageModel> result = [];

    for (final e in raw) {
      try {
        final map = e as Map<String, dynamic>;
        debugPrint('[Chat] item keys: ${map.keys.toList()}');

        // NEW backend: {_id, chatId, peer:{...}, isMine, text, createdAt}
        if (map['peer'] is Map) {
          debugPrint('[Chat] NEW format - peer: ${map['peer']}');
          result.add(MessageModel.fromJson(map));
          continue;
        }

        // OLD backend: {_id: "chatId", lastMessage: {...}}
        final chatId = map['_id']?.toString() ?? '';
        final rawMsg = map['lastMessage'];
        final msg = rawMsg is Map<String, dynamic> ? rawMsg : map;
        debugPrint('[Chat] OLD format - chatId=$chatId msg keys: ${msg.keys.toList()}');

        if (chatId.isEmpty || !chatId.contains('_')) continue;

        final parts = chatId.split('_');
        debugPrint('[Chat] chatId parts: $parts, myId: $myId');

        final peerId = parts.firstWhere(
          (p) => p.isNotEmpty && p != myId,
          orElse: () => '',
        );
        debugPrint('[Chat] peerId=$peerId');
        if (peerId.isEmpty) continue;

        final peer = await _fetchUser(peerId);
        debugPrint('[Chat] peer=${peer?.username}');
        if (peer == null) continue;

        final senderRaw = msg['sender'];
        final senderStr = senderRaw?.toString() ?? '';
        final isMine = myId.isNotEmpty && senderStr == myId;

        DateTime createdAt;
        try { createdAt = DateTime.parse(msg['createdAt'].toString()); }
        catch (_) { createdAt = DateTime.now(); }

        result.add(MessageModel(
          id: msg['_id']?.toString() ?? chatId,
          chatId: chatId,
          peer: peer,
          text: msg['text']?.toString() ?? '',
          createdAt: createdAt,
          isMine: isMine,
        ));
      } catch (err, st) {
        debugPrint('[Chat] item error: $err\n$st');
      }
    }

    debugPrint('[Chat] result count: ${result.length}');
    return result;
  }

  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final myId = await _getMyId();
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat: ${chatRes.statusCode}');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final msgRes = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (msgRes.statusCode >= 400) throw Exception('Failed to load messages');
    final body = jsonDecode(msgRes.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data
        .map((e) => MessageModel.fromRoomJson(e as Map<String, dynamic>, myId))
        .toList();
  }

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
    if (res.statusCode >= 400) throw Exception('Send failed: ${res.body}');
    return MessageModel.fromRoomJson(
        jsonDecode(res.body) as Map<String, dynamic>, myId);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }
}
