import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';

class ChatApi {
  static Future<List<dynamic>> getChats() async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats'),
    );

    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getMessages(String chatId) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
    );

    return jsonDecode(res.body);
  }

  static Future<void> sendMessage(String chatId, String text) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
  }
}
