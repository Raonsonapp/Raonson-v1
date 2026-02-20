import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _i = SocketService._internal();
  factory SocketService() => _i;
  SocketService._internal();

  io.Socket? socket;

  void connect(String userId) {
    socket ??= io.io(
      'https://raonson-v1.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      socket!.emit('online', userId);
    });
  }

  void on(String event, Function(dynamic) cb) {
    socket?.on(event, cb);
  }

  void emit(String event, dynamic data) {
    socket?.emit(event, data);
  }

  void disconnect() {
    socket?.disconnect();
  }
}
