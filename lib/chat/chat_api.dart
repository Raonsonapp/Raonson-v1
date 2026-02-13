import '../core/api.dart';

class ChatApi {
  static Future<void> sendMessage(String chatId, String text) async {
    await Api.post(
      '/chats/$chatId/messages',
      body: {'text': text},
    );
  }
}
