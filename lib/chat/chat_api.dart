import 'dart:convert';
import '../core/api.dart';

class ChatApi {
  /// GET /chats
  static Future<List<dynamic>> getChats() async {
    final res = await Api.get('/chats');
    return jsonDecode(res.body);
  }

  /// GET /chats/:id/messages
  static Future<List<dynamic>> getMessages(String chatId) async {
    final res = await Api.get('/chats/$chatId/messages');
    return jsonDecode(res.body);
  }

  /// POST /chats/:id/messages
  static Future<void> sendMessage(String chatId, String text) async {
    await Api.post(
      '/chats/$chatId/messages',
      body: {'text': text},
    );
  }
}
