// lib/core/network/socket_client.dart
import '../services/socket_service.dart';

class SocketClient {
  static final _s = SocketService.instance;
  static Future<void> connect() => _s.autoConnect();
  static void emit(String event, dynamic data) => _s.emit(event, data);
  static void on(String event, Function(dynamic) handler) =>
      _s.on(event, (d) => handler(d));
  static void off(String event) => _s.off(event);
  static void disconnect() => _s.disconnect();
}
