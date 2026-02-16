import '../core/api.dart';

class ChatApi {
  static Future<List<dynamic>> fetchChats() async {
    final res = await Api.get('/chats');
    return res;
  }

  static Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    await Api.post('/chats/send', {
      'chatId': chatId,
      'text': text,
    });
  }

  static Future<void> markSeen(String chatId) async {
    await Api.post('/chats/$chatId/seen', {});
  }
}
