// lib/core/webrtc_service.dart
import 'package:flutter/foundation.dart';
import 'services/socket_service.dart';
import 'storage/token_storage.dart';

typedef VoidFn         = void Function();
typedef IncomingCallFn = void Function(
    String from, String fromUsername, String fromAvatar, String callType);

class WebRTCService extends ChangeNotifier {
  static final WebRTCService _i = WebRTCService._();
  factory WebRTCService() => _i;
  WebRTCService._();

  final _socket     = SocketService.instance;
  bool  _registered = false;

  IncomingCallFn? onIncomingCall;
  VoidFn?         onCallEnded;
  VoidFn?         onCallDeclined;
  VoidFn?         onCallAnswered;

  /// Гузариш дар миёни гуфтугӯ (`call:switch`): mode video|voice,
  /// action request|accept|decline|cancel|apply.
  void Function(String from, String mode, String action)? onCallSwitch;

  /// Намоиши экрани ҳамсӯҳбат (`call:screen`): action start|stop.
  void Function(String from, String action)? onCallScreen;

  bool get isConnected => _socket.isConnected;

  Future<void> connect() async {
    if (_registered) return;
    await _socket.autoConnect();
    final uid = await TokenStorage.getUserId();
    if (uid != null && uid.isNotEmpty) {
      _socket.emit('user:register', uid);
    }
    _socket.on('call:incoming', (data) {
      if (data is! Map) return;
      onIncomingCall?.call(
        data['from']         ?? '',
        data['fromUsername'] ?? 'Unknown',
        data['fromAvatar']   ?? '',
        data['callType']     ?? 'voice',
      );
    });
    _socket.on('call:answered', (_) => onCallAnswered?.call());
    _socket.on('call:ended',    (_) => onCallEnded?.call());
    _socket.on('call:declined', (_) => onCallDeclined?.call());
    _socket.on('call:switch', (data) {
      if (data is! Map) return;
      onCallSwitch?.call(
        (data['from'] ?? '').toString(),
        (data['mode'] ?? '').toString(),
        (data['action'] ?? '').toString(),
      );
    });
    _socket.on('call:screen', (data) {
      if (data is! Map) return;
      onCallScreen?.call(
        (data['from'] ?? '').toString(),
        (data['action'] ?? '').toString(),
      );
    });
    _registered = true;
    debugPrint('[WebRTC] registered');
  }

  void notifyIncoming({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required String fromAvatar,
    required bool   isVideo,
  }) => _socket.emit('call:offer', {
    'to': toUserId, 'from': fromUserId,
    'fromUsername': fromUsername, 'fromAvatar': fromAvatar,
    'callType': isVideo ? 'video' : 'voice', 'offer': {},
  });

  void sendAnswered(String to) =>
      _socket.emit('call:answer', {'to': to, 'answer': {}});
  void sendDecline(String to) =>
      _socket.emit('call:decline', {'to': to});
  void sendEnd(String to) =>
      _socket.emit('call:end', {'to': to});
  void sendSwitch(String to, {required String mode, required String action}) =>
      _socket.emit('call:switch', {'to': to, 'mode': mode, 'action': action});
  void sendScreen(String to, {required bool sharing}) =>
      _socket.emit('call:screen', {'to': to, 'action': sharing ? 'start' : 'stop'});
}
