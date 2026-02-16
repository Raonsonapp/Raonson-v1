import '../core/api.dart';
import 'dart:convert';

class ChatApi {
  static Future<List> getChats() async {
    final res = await Api.get('/chats');
    return jsonDecode(res.body);
  }

  static Future<void> sendMessage(String chatId, String text) async {
    await Api.post('/chats/send', {
      'chatId': chatId,
      'text': text,
    });
  }
}
