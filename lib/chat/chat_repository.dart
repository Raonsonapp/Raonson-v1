import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  // GET INBOX CHATS
  Future<List<MessageModel>> getInboxChats() async {
    final response = await _api.getRequest(ApiEndpoints.chat);
    if (response.statusCode == 401) throw Exception('Unauthorized');
    if (response.statusCode >= 400) throw Exception('Server error ${response.statusCode}');
    final body = jsonDecode(response.body);
    final List data = body is List ? body : (body['chats'] ?? []);
    return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // GET MESSAGES WITH USER — first get/create chatId, then load messages
  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    // Step 1: get chatId
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    // Step 2: load messages
    final msgRes = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (msgRes.statusCode >= 400) throw Exception('Failed to load messages');
    final body = jsonDecode(msgRes.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // SEND MESSAGE — toUserId matches old screen API
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
  }) async {
    // Step 1: get/create chatId
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId');
    if (chatRes.statusCode >= 400) throw Exception('Failed to get chat');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    // Step 2: send message
    final response = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': toUserId, 'text': text},
    );
    if (response.statusCode >= 400) throw Exception('Send failed');
    return MessageModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // MARK AS READ
  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }

  // DELETE
  Future<void> deleteChat(String peerId) async {
    await _api.deleteRequest('${ApiEndpoints.chat}/$peerId');
  }
}
