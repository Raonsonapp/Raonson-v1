import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient.instance;

  // =========================
  // 📥 GET CHAT LIST (INBOX)
  // =========================
  Future<List<MessageModel>> getInboxChats() async {
    final response = await _api.getRequest(
      ApiEndpoints.chat,
    );

    final List data = jsonDecode(response.body) as List;
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  // =========================
  // 💬 GET MESSAGES WITH USER
  // =========================
  Future<List<MessageModel>> getMessagesWithUser(String userId) async {
    final response = await _api.getRequest(
      '${ApiEndpoints.chat}/$userId',
    );

    final List data = jsonDecode(response.body) as List;
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  // =========================
  // ✉️ SEND MESSAGE
  // =========================
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
  }) async {
    final response = await _api.postRequest(
      ApiEndpoints.chat,
      body: {
        'to': toUserId,
        'text': text,
      },
    );

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    return MessageModel.fromJson(data);
  }

  // =========================
  // 👁️ MARK CHAT AS READ
  // =========================
  Future<void> markAsRead(String peerId) async {
    await _api.postRequest(
      '${ApiEndpoints.chat}/$peerId/read',
    );
  }

  // =========================
  // 🧹 DELETE CHAT
  // =========================
  Future<void> deleteChat(String peerId) async {
    await _api.deleteRequest(
      '${ApiEndpoints.chat}/$peerId',
    );
  }
}
