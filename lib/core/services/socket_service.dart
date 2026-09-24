// lib/core/services/socket_service.dart
// ✅ socket_io_client → web_socket_channel (Go backend)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../app/app_config.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';

class SocketService {
  SocketService._() {
    TokenStorage.onUserChanged = (uid) { _onUserChanged(uid); };
  }
  static final SocketService instance = SocketService._();

  WebSocketChannel?            _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connected  = false;
  bool _connecting = false;

  // ── Auto-reconnect (exponential backoff) ──
  bool        _manualClose = false; // disconnect()-и дастӣ → reconnect нашавад
  String?     _lastToken;
  int         _retry = 0;
  Timer?      _reconnectTimer;

  /// Оё аз сервер ҳадди ақал як фрейм омад?
  ///
  /// Бе ин пайвасти РАДШУДА (401) ҳамчун муваффақ ҳисоб мешуд.
  bool        _handshakeOk = false;

  /// Чанд бор пай дар пай пайваст нашуд БЕ як фрейм.
  ///
  /// Ин аломати токени кӯҳна аст, на шабакаи бад.
  int         _authFailures = 0;

  final Map<String, List<void Function(dynamic)>> _listeners = {};

  bool get isConnected => _connected;

  /// Корбаре, ки СЕРВЕР ин сокетро ба ӯ тааллуқ медонад (аз `socket:ready`).
  ///
  /// ⚠️ Пеш аз ин маълум набуд. Баъди иловаи аккаунти дуюм сокет бо
  /// token-и аккаунти КӮҲНА пайваст мемонд — паёме, ки корбар аз
  /// «tajikshop» ба «raonson» менавишт, дар сервер ҳамчун паёми
  /// «raonson → tajikshop» сабт мешуд ва дар экран аз тарафи чап меомад.
  String? _userId;
  String? get userId => _userId;

  /// Сокет ба ҳамин корбар тааллуқ дорад? (агар ҳанӯз маълум набошад — не)
  bool isFor(String uid) => _connected && _userId != null && _userId == uid;

  Future<void> connect(String token) async {
    if (_connected || _connecting) return;
    _connecting = true;
    _manualClose = false;
    _lastToken = token;

    final wsUrl = AppConfig.apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws?token=$token'),
      );
      _sub = _channel!.stream.listen(
        (raw) {
          // ⚠️ Муваффақият МАҲЗ ИН ҶО тасдиқ мешавад.
          //
          // `WebSocketChannel.connect` косил аст: он ҳатто ҳангоми
          // 401 хато намедиҳад ва фавран бармегардад. Пештар код
          // фавран `_retry = 0` мекард — пас фосилаи такрор ҲЕҶ ГОҲ
          // намеафзуд ва телефон ҳар сония серверро мезад, абадан.
          //
          // Аввалин фрейми ҳақиқӣ ягона нишонаи пайвасти воқеӣ аст.
          if (!_handshakeOk) {
            _handshakeOk = true;
            _retry = 0;
            debugPrint('[Socket] connected ✅');
          }
          try {
            final msg   = jsonDecode(raw as String) as Map<String, dynamic>;
            final event = msg['event'] as String? ?? '';
            final data  = msg['data'];
            if (event == 'socket:ready') {
              if (data is Map) _userId = data['userId']?.toString();
              return;
            }
            _dispatch(event, data);
          } catch (e) {
            debugPrint('[Socket] parse: $e');
          }
        },
        onDone:  () { _onClosed(); },
        onError: (e) { debugPrint('[Socket] error: $e'); _onClosed(); },
        cancelOnError: false,
      );
      _connected  = true;
      _connecting = false;
    } catch (e) {
      _connecting = false;
      debugPrint('[Socket] connect failed: $e');
      _scheduleReconnect();
    }
  }

  // Пайваст канда шуд (onDone/onError) — агар дастӣ набошад, дубора пайваст шав.
  void _onClosed() {
    _userId     = null;
    _connected  = false;
    _connecting = false;
    // Пайваст канда шуд, вале ҳеҷ фрейм наомада буд → эҳтимол 401.
    if (!_handshakeOk) _authFailures++;
    _handshakeOk = false;
    _sub?.cancel();
    _channel = null;
    if (_manualClose) return;
    _scheduleReconnect();
  }

  // Exponential backoff: 1с, 2с, 4с, 8с, 16с, ... (макс 30с).
  void _scheduleReconnect() {
    if (_manualClose) return;
    _reconnectTimer?.cancel();
    final delay = (1 << _retry).clamp(1, 30); // 1,2,4,8,16,30…
    if (_retry < 5) _retry++;
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      if (_manualClose) return;

      // ⚠️ Токен ҲАМЕША аз захира гирифта мешавад, на аз хотира.
      //
      // Пештар `_lastToken` авлотар буд. Вақте токени дастрасӣ
      // мӯҳлаташ мегузашт, дархостҳои оддӣ онро нав мекарданд, вале
      // сокет ҳамон токени КӮҲНАро абадан такрор мекард — 401, 401,
      // 401… Дар лог ин ҳар ду сония дида мешуд.
      //
      // Маҳз ҳамин зангро мекушт: `call:offer` тавассути сокет
      // меравад, ва сокет ҳеҷ гоҳ пайваст набуд.
      var token = await TokenStorage.getAccessToken();

      // Агар чанд бор пай дар пай ягон фрейм наомада бошад, токен
      // кӯҳна аст — онро нав мекунем.
      if (_authFailures >= 2) {
        final ok = await ApiClient.instance.refreshSession();
        if (ok) {
          token = await TokenStorage.getAccessToken();
          _authFailures = 0;
        }
      }

      token ??= _lastToken;
      if (token != null && token.isNotEmpty) {
        await connect(token);
      }
    });
  }

  Future<void> autoConnect() async {
    if (_connected) return;
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) await connect(token);
  }

  // Пас аз иваз кардани аккаунт: socket-и корбари куҳнаро мебандем ва
  // бо токени нав аз нав пайваст мешавем, то presence/online status/
  // зангҳо ба аккаунти нав дуруст рафтор кунанд.
  //
  // Шунавандаҳо НИГОҲ дошта мешаванд: `WebRTCService` онҳоро як бор
  // мегузорад — пок кардан зангҳои воридшавандаро то бозоғозии барнома
  // мекушт.
  Future<void> reconnectAs(String newToken) async {
    if (newToken.isEmpty) return;
    _closeChannel();
    _manualClose = false;
    await connect(newToken);
  }

  void _closeChannel() {
    _manualClose = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null; _connected = false; _connecting = false;
    _userId = null;
  }

  Future<void> _onUserChanged(String uid) async {
    if (_userId == uid) return;
    if (!_connected && !_connecting) return; // пайваст нест — баъдтар бо token-и нав
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) await reconnectAs(token);
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

  /// Шунавандаро хориҷ мекунад.
  ///
  /// Бо [cb] — ТАНҲО ҳамонро. Бе он — ҳамаи шунавандаҳои ҳодисаро.
  ///
  /// ⚠️ Пеш танҳо варианти дуюм буд. Чат A → ақиб → фавран чат B:
  /// `dispose`-и A баъди аниматсияи бозгашт (~300ms) меояд, яъне
  /// БАЪДИ он ки B шунавандаҳои худро гузошт — ва онҳоро ҳам пок
  /// мекард. Дар чат B паёмҳои нав дигар фавран намеомаданд.
  void off(String event, [void Function(dynamic)? cb]) {
    if (cb == null) {
      _listeners.remove(event);
      return;
    }
    final list = _listeners[event];
    if (list == null) return;
    list.remove(cb);
    if (list.isEmpty) _listeners.remove(event);
  }

  /// Шумораи шунавандаҳо — танҳо барои тестҳо.
  @visibleForTesting
  int listenerCount(String event) => _listeners[event]?.length ?? 0;

  void joinChat(String chatId) =>
      emit('chat:join', {'chatId': chatId});

  /// Ба шунавандаҳо даст НАМЕРАСОНАД — ҳар экран худаш шунавандаи
  /// ХУДАШРО хориҷ мекунад. Пеш ин ҷо `off('chat:new')` буд, ки
  /// шунавандаи чати ДИГАР-ро низ пок мекард.
  void leaveChat(String chatId) {}

  void sendTyping(String chatId, String userId, {bool isTyping = true}) =>
      emit('chat:typing',
          {'chatId': chatId, 'receiver': userId, 'isTyping': isTyping});

  void onNewMessage(void Function(Map<String, dynamic>) cb) =>
      on('chat:new', (d) { if (d is Map<String, dynamic>) cb(d); });

  void onTyping(void Function(String) cb) =>
      on('chat:typing', (d) {
        if (d is Map && d['userId'] != null) cb(d['userId'] as String);
      });

  void offNewMessage() => off('chat:new');
  void offTyping()     => off('chat:typing');

  void disconnect() {
    _closeChannel();
    _listeners.clear();
  }

  /// Баромадан аз ҳисоб: пайвастро мебандад, то телефон паём ва зангҳои
  /// корбари баромада-ро нагирад. Шунавандаҳо мемонанд — барои корбари
  /// навбатӣ (занг ва ғ.) боз лозиманд.
  void closeForLogout() => _closeChannel();

  // ── Test hooks ──
  @visibleForTesting
  bool get reconnectPending => _reconnectTimer?.isActive ?? false;

  @visibleForTesting
  void debugTriggerDisconnect() => _onClosed();

  @visibleForTesting
  void debugReset() {
    _reconnectTimer?.cancel();
    _retry = 0;
    _manualClose = false;
    _connected = false;
    _connecting = false;
  }

  void _dispatch(String event, dynamic data) {
    final cbs = _listeners[event];
    if (cbs == null) return;
    for (final cb in List.of(cbs)) {
      try { cb(data); } catch (e) { debugPrint('[Socket] cb error: $e'); }
    }
  }
}
