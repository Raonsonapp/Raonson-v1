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
}
