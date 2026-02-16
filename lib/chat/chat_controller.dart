import 'package:flutter/material.dart';
import '../core/socket_service.dart';
import 'message_model.dart';

class ChatController extends ChangeNotifier {
  final List<Message> messages = [];

  void init(String userId, String chatId) {
    final socket = SocketService();
    socket.connect(userId);

    socket.on('new_message', (data) {
      if (data['chatId'] == chatId) {
        messages.add(Message.fromJson(data['message']));
        notifyListeners();
      }
    });
  }

  void sendMessage(String chatId, String text) {
    SocketService().emit('send_message', {
      'chatId': chatId,
      'text': text,
    });
  }
}
