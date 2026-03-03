import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../app/app_config.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (isConnected) return;
    _socket = IO.io(
      AppConfig.apiBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
  }

  void joinChat(String chatId) =>
      _socket?.emit('chat:join', {'conversationId': chatId});

  void leaveChat(String chatId) {
    _socket?.off('chat:new');
    _socket?.off('chat:typing');
  }

  void sendTyping(String chatId, String userId) =>
      _socket?.emit('chat:typing', {'conversationId': chatId, 'userId': userId});

  void onNewMessage(void Function(Map<String, dynamic>) cb) {
    _socket?.on('chat:new', (data) {
      if (data is Map<String, dynamic>) cb(data);
    });
  }

  void onTyping(void Function(String) cb) {
    _socket?.on('chat:typing', (data) {
      if (data is Map && data['userId'] != null) cb(data['userId'] as String);
    });
  }

  void offNewMessage() => _socket?.off('chat:new');
  void offTyping() => _socket?.off('chat:typing');

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
