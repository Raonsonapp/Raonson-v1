import 'dart:convert';
import '../core/api.dart';

class ChatApi {
  static Future<List<dynamic>> getChats() async {
    final res = await Api.get('/chats');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Load chats failed');
  }

  static Future<List<dynamic>> getMessages(String chatId) async {
    final res = await Api.get('/chats/$chatId/messages');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Load messages failed');
  }

  static Future<void> sendMessage(String chatId, String text) async {
    await Api.post('/chats/$chatId/messages', {
      'text': text,
    });
  }
}
