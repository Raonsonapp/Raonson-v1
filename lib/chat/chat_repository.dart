import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';
import '../core/services/user_session.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;
  String get _myId => UserSession.userId ?? '';

  // GET INBOX - backend returns [{_id, peer:{...}, isMine, text, createdAt}]
  Future<List<MessageModel>> getInboxChats() async {
    final res = await _api.getRequest(ApiEndpoints.chat);
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Server error');
    final body = jsonDecode(res.body);
    final List data = body is List ? body : (body['chats'] ?? []);
    return data
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .where((m) => m.peer.username.isNotEmpty)
        .toList();
  }

  // GET MESSAGES IN ROOM
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
