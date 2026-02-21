import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<MessageModel>> getInboxChats() async {
    final response = await _api.getRequest(ApiEndpoints.chat);

    if (response.statusCode == 401) throw Exception('Unauthorized');
    if (response.statusCode >= 400) throw Exception('Server error ${response.statusCode}');

    final body = jsonDecode(response.body);
    final List data = body is List ? body : (body['chats'] ?? []);
    return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MessageModel>> getMessagesWithUser(String chatId) async {
    final response = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');

    if (response.statusCode >= 400) throw Exception('Failed to load messages');

    final body = jsonDecode(response.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MessageModel> sendMessage({
    required String chatId,
    required String receiverId,
    required String text,
  }) async {
    final response = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': receiverId, 'text': text},
    );
    if (response.statusCode >= 400) throw Exception('Send failed');
    return MessageModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }

  Future<void> deleteChat(String peerId) async {
    await _api.deleteRequest('${ApiEndpoints.chat}/$peerId');
  }
}
