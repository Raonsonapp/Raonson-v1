import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatRepository {
  final ApiClient _api;

  ChatRepository(this._api);

  // =========================
  // 📥 GET CHAT LIST (INBOX)
  // =========================
  Future<List<UserModel>> getChatUsers() async {
    final res = await _api.get(ApiEndpoints.chatList);

    final List data = res as List;
    return data.map((e) => UserModel.fromJson(e)).toList();
  }

  // =========================
  // 💬 GET MESSAGES WITH USER
  // =========================
  Future<List<MessageModel>> getMessagesWithUser(String userId) async {
    final res = await _api.get(
      ApiEndpoints.chatMessages(userId),
    );

    final List data = res as List;
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  // =========================
  // ✉️ SEND MESSAGE
  // =========================
  Future<MessageModel> sendMessage({
    required String toUserId,
    required String text,
  }) async {
    final res = await _api.post(
      ApiEndpoints.sendMessage,
      body: {
        'to': toUserId,
        'text': text,
      },
    );

    return MessageModel.fromJson(res);
  }

  // =========================
  // 👁️ MARK AS READ
  // =========================
  Future<void> markAsRead(String peerId) async {
    await _api.post(
      ApiEndpoints.markChatRead(peerId),
    );
  }

  // =========================
  // 🧹 DELETE CHAT (OPTIONAL)
  // =========================
  Future<void> deleteChat(String peerId) async {
    await _api.delete(
      ApiEndpoints.deleteChat(peerId),
    );
  }
}
