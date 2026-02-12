import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';
import 'chat_model.dart';

class ChatApi {
  static Future<List<Message>> getMessages(String chatId) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/chats/$chatId/messages'),
    );

    final List data = jsonDecode(res.body);
    return data.map((e) => Message.fromJson(e)).toList();
  }
}
