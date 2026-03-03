import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../app/app_config.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;

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
    _socket!.on('connect', (_) => print('[Socket] connected'));
    _socket!.on('disconnect', (_) => print('[Socket] disconnected'));
    _socket!.on('connect_error', (e) => print('[Socket] error: $e'));
  }

  void joinChat(String chatId) {
    _socket?.emit('chat:join', {'conversationId': chatId});
  }

  void leaveChat(String chatId) {
    _socket?.off('chat:new');
  }

  void sendTyping(String chatId, String userId) {
    _socket?.emit('chat:typing', {'conversationId': chatId, 'userId': userId});
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('chat:new', (data) {
      if (data is Map<String, dynamic>) callback(data);
    });
  }

  void onTyping(Function(String) callback) {
    _socket?.on('chat:typing', (data) {
      if (data is Map && data['userId'] != null) {
        callback(data['userId'] as String);
      }
    });
  }

  void offTyping() => _socket?.off('chat:typing');
  void offNewMessage() => _socket?.off('chat:new');

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
