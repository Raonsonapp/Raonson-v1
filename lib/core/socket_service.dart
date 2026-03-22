// lib/core/services/socket_service.dart
// ✅ socket_io_client → web_socket_channel (Go backend)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../app/app_config.dart';
import '../storage/token_storage.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  WebSocketChannel?            _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connected  = false;
  bool _connecting = false;

  final Map<String, List<void Function(dynamic)>> _listeners = {};

  bool get isConnected => _connected;

  Future<void> connect(String token) async {
    if (_connected || _connecting) return;
    _connecting = true;

    final wsUrl = AppConfig.apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws?token=$token'),
      );
      _sub = _channel!.stream.listen(
        (raw) {
          try {
            final msg   = jsonDecode(raw as String) as Map<String, dynamic>;
            final event = msg['event'] as String? ?? '';
            final data  = msg['data'];
            _dispatch(event, data);
          } catch (e) {
            debugPrint('[Socket] parse: $e');
          }
        },
        onDone:  () { _connected = false; _connecting = false; },
        onError: (e) { _connected = false; _connecting = false; debugPrint('[Socket] error: $e'); },
        cancelOnError: false,
      );
      _connected  = true;
      _connecting = false;
      debugPrint('[Socket] connected ✅');
    } catch (e) {
      _connecting = false;
      debugPrint('[Socket] connect failed: $e');
    }
  }

  Future<void> autoConnect() async {
    if (_connected) return;
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) await connect(token);
  }

  void emit(String event, dynamic data) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
    } catch (e) {
      debugPrint('[Socket] emit error: $e');
    }
  }

  void on(String event, void Function(dynamic) cb) =>
      _listeners.putIfAbsent(event, () => []).add(cb);

  void off(String event) => _listeners.remove(event);

  void joinChat(String chatId) =>
      emit('chat:join', {'chatId': chatId});

  void leaveChat(String chatId) {
    off('chat:new');
    off('chat:typing');
  }

  void sendTyping(String chatId, String userId) =>
      emit('chat:typing', {'chatId': chatId, 'receiver': userId});

  void onNewMessage(void Function(Map<String, dynamic>) cb) =>
      on('chat:new', (d) { if (d is Map<String, dynamic>) cb(d); });

  void onTyping(void Function(String) cb) =>
      on('chat:typing', (d) {
        if (d is Map && d['userId'] != null) cb(d['userId'] as String);
      });

  void offNewMessage() => off('chat:new');
  void offTyping()     => off('chat:typing');

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null; _connected = false; _connecting = false;
    _listeners.clear();
  }

  void _dispatch(String event, dynamic data) {
    final cbs = _listeners[event];
    if (cbs == null) return;
    for (final cb in List.of(cbs)) {
      try { cb(data); } catch (e) { debugPrint('[Socket] cb error: $e'); }
    }
  }
}
