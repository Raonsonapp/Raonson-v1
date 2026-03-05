import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  static String? _myId;

  Future<String> _getMyId() async {
    if (_myId != null && _myId!.isNotEmpty) return _myId!;
    try {
      final res = await _api.get('/profile/me');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user = body.containsKey('user') ? body['user'] as Map : body;
        _myId = (user['_id'] ?? user['id'])?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('[Chat] getMyId: $e');
    }
    return _myId ?? '';
  }

  Future<List<MessageModel>> getInboxChats() async {
    final res = await _api.getRequest(ApiEndpoints.chat);
    if (res.statusCode == 401) throw Exception('Unauthorized');
    if (res.statusCode >= 400) throw Exception('Server error ${res.statusCode}');

    final body = jsonDecode(res.body);
    final List raw = body is List ? body : (body['chats'] ?? []);

    final result = <MessageModel>[];
    for (final e in raw) {
      try {
        result.add(MessageModel.fromJson(e as Map<String, dynamic>));
      } catch (err) {
        debugPrint('[Chat] parse: $err');
      }
    }
    return result;
  }

  Future<List<MessageModel>> getMessagesWithUser(String peerId) async {
    final myId = await _getMyId();
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$peerId');
    if (chatRes.statusCode >= 400) throw Exception('Chat not found');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final msgRes = await _api.getRequest('${ApiEndpoints.chat}/$chatId/messages');
    if (msgRes.statusCode >= 400) throw Exception('Messages not found');
    final body = jsonDecode(msgRes.body);
    final List data = body is Map ? (body['messages'] ?? []) : body as List;
    return data.map((e) => MessageModel.fromRoomJson(e as Map<String, dynamic>, myId)).toList();
  }

  Future<MessageModel> sendMessage({required String toUserId, required String text}) async {
    final myId = await _getMyId();
    final chatRes = await _api.getRequest('${ApiEndpoints.chat}/with/$toUserId');
    if (chatRes.statusCode >= 400) throw Exception('Chat not found');
    final chatId = (jsonDecode(chatRes.body) as Map)['chatId'] as String;

    final res = await _api.postRequest(
      '${ApiEndpoints.chat}/$chatId/messages',
      body: {'receiverId': toUserId, 'text': text},
    );
    if (res.statusCode >= 400) throw Exception('Send failed');
    return MessageModel.fromRoomJson(jsonDecode(res.body) as Map<String, dynamic>, myId);
  }

  Future<void> markAsRead(String chatId) async {
    await _api.postRequest('${ApiEndpoints.chat}/$chatId/read');
  }
}
