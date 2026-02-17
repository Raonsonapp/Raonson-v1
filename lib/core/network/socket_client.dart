import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../app/app_config.dart';
import '../storage/token_storage.dart';

class SocketClient {
  static io.Socket? _socket;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await TokenStorage.getAccessToken();

    _socket = io.io(
      AppConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setExtraHeaders({
            if (token != null) 'Authorization': 'Bearer $token',
          })
          .build(),
    );

    _socket!.connect();
  }

  static io.Socket get socket {
    if (_socket == null) {
      throw Exception('Socket not connected');
    }
    return _socket!;
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static void emit(String event, dynamic data) {
    socket.emit(event, data);
  }

  static void on(String event, Function(dynamic) handler) {
    socket.on(event, handler);
  }

  static void off(String event) {
    socket.off(event);
  }
}
