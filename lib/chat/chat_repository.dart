import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/storage/token_storage.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  // Get my userId from secure storage (saved during login)
  Future<String> _myId() async {
    return await TokenStorage.getUserId() ?? '';
  }

  Future<List<MessageModel>> getInboxChats() async {
    final res = await _api.getRequest(ApiEndpoints.chat);
    if (res.statusCode >= 400) throw Exception('Error ${res.statusCode}');

    final body = jsonDecode(res.body);
    final List raw = body is List ? body : (body['chats'] ?? []);

    final out = <MessageModel>[];
    for (final e in raw) {
      try {
        final m = MessageModel.fromJson(e as Map<String, dynamic>);
        if (m.peer.username.isNotEmpty) out.add(m);
      } catch (err) {
        debugPrint('[Chat] parse: $err');
      }
    }
    return out;
  }

  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final myId = await _myId();
    final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (cr.statusCode >= 400) throw Exception('Chat error');
    final chatId = (jsonDecode(cr.body) as Map)['chatId'] as String;

    final mr = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (mr.statusCode >= 400) throw Exception('Messages error');
    final body = jsonDecode(mr.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data
        .map((e) => MessageModel.fromRoomJson(e as Map<String, dynamic>, myId))
        .toList();
  }

  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
  }) async {
    final myId = await _myId();
    final cr = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId');
    if (cr.statusCode >= 400) throw Exception('Chat error');
    final chatId = (jsonDecode(cr.body) as Map)['chatId'] as String;

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': toUserId, 'text': text},
    );
    if (res.statusCode >= 400) throw Exception('Send error');
    return MessageModel.fromRoomJson(
        jsonDecode(res.body) as Map<String, dynamic>, myId);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }
}
