import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';
import 'chat_model.dart';
import 'message_model.dart';

class ChatApi {
  static Future<List<Chat>> getChats() async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats'),
    );

    final List data = jsonDecode(res.body);
    return data.map((e) => Chat.fromJson(e)).toList();
  }

  static Future<List<Message>> getMessages(String chatId) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
    );

    final List data = jsonDecode(res.body);
    return data.map((e) => Message.fromJson(e)).toList();
  }

  static Future<void> sendMessage(
    String chatId,
    String text,
  ) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
  }
}
