import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../app/app_config.dart';
import 'storage/token_storage.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  WebSocketChannel?            _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connected  = false;
  bool _connecting = false;
  bool _disposed   = false;

  // Auto-reconnect
  Timer?  _reconnectTimer;
  int     _retryCount = 0;
  static const _maxRetry    = 8;
  static const _baseDelaySec = 2;

  final Map<String, List<void Function(dynamic)>> _listeners = {};

  bool get isConnected => _connected;

  // ── Connect ──────────────────────────────────────────────────────
  Future<void> connect(String token) async {
    if (_connected || _connecting || _disposed) return;
    _connecting = true;
    _cancelReconnect();

    final wsUrl = AppConfig.apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws?token=$token'),
      );
      _sub = _channel!.stream.listen(
        _onMessage,
        onDone:  () => _onDisconnected(token),
        onError: (e) {
          debugPrint('[Socket] error: $e');
          _onDisconnected(token);
        },
        cancelOnError: false,
      );
      _connected  = true;
      _connecting = false;
      _retryCount = 0;
      debugPrint('[Socket] connected ✅');
    } catch (e) {
      _connecting = false;
      debugPrint('[Socket] connect failed: $e');
      _scheduleReconnect(token);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg   = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';
      final data  = msg['data'];
      _dispatch(event, data);
    } catch (e) {
      debugPrint('[Socket] parse: $e');
    }
  }

  void _onDisconnected(String token) {
    _connected  = false;
    _connecting = false;
    debugPrint('[Socket] disconnected, retry $_retryCount');
    if (!_disposed) _scheduleReconnect(token);
  }

  // ── Auto-reconnect — exponential backoff ─────────────────────────
  void _scheduleReconnect(String token) {
    if (_retryCount >= _maxRetry || _disposed) return;
    _cancelReconnect();
    final delay = Duration(
      seconds: (_baseDelaySec * (1 << _retryCount)).clamp(2, 60),
    );
    _retryCount++;
    debugPrint('[Socket] retry #$_retryCount in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () => connect(token));
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ── Auto-connect (token-ро худаш мегирад) ────────────────────────
  Future<void> autoConnect() async {
    if (_connected) return;
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) await connect(token);
  }

  // ── Ping — keep-alive ────────────────────────────────────────────
  Timer? _pingTimer;

  void startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_connected) emit('ping', {});
    });
  }

  void stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ── Emit ─────────────────────────────────────────────────────────
  void emit(String event, dynamic data) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
    } catch (e) {
      debugPrint('[Socket] emit error: $e');
    }
  }

  // ── Listeners ────────────────────────────────────────────────────
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

  // ── Disconnect ───────────────────────────────────────────────────
  void disconnect() {
    _disposed = false; // рехо — дубора пайваст кардан мумкин
    _cancelReconnect();
    stopPing();
    _sub?.cancel();
    _channel?.sink.close();
    _channel    = null;
    _connected  = false;
    _connecting = false;
    _retryCount = 0;
  }

  void dispose() {
    _disposed = true;
    disconnect();
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
