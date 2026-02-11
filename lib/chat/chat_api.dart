import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'chat_model.dart';

class ChatApi {
  static Future<List<Chat>> getChats() async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Chat.fromJson(e)).toList();
  }

  static Future<List<Message>> getMessages(String chatId) async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Message.fromJson(e)).toList();
  }

  static Future<void> sendMessage(String chatId, String text) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );
  }
}
