import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/storage/token_storage.dart';

typedef VoidFn         = void Function();
typedef IncomingCallFn = void Function(
  String from, String fromUsername, String fromAvatar, String callType);

/// Socket.io signaling — singleton.
/// Handles: notify peer of incoming call, answer, decline, end.
class WebRTCService extends ChangeNotifier {
  static final WebRTCService _i = WebRTCService._();
  factory WebRTCService() => _i;
  WebRTCService._();

  io.Socket? _socket;
  bool _connecting = false;

  IncomingCallFn? onIncomingCall;
  VoidFn?         onCallEnded;
  VoidFn?         onCallDeclined;
  VoidFn?         onCallAnswered;

  bool get isConnected => _socket?.connected == true;

  // ─── CONNECT (safe to call many times) ───
  Future<void> connect() async {
    if (_socket?.connected == true || _connecting) return;
    _connecting = true;

    _socket = io.io(
      'https://raonson-v1.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) async {
      _connecting = false;
      final uid = await TokenStorage.getUserId();
      if (uid != null && uid.isNotEmpty) {
        _socket!.emit('user:register', uid);
        debugPrint('[Signal] registered: $uid');
      }
    });

    _socket!.on('call:incoming', (data) {
      debugPrint('[Signal] incoming from ${data['from']}');
      onIncomingCall?.call(
        data['from']         ?? '',
        data['fromUsername'] ?? 'Unknown',
        data['fromAvatar']   ?? '',
        data['callType']     ?? 'voice',
      );
    });

    _socket!.on('call:answered',  (_) { debugPrint('[Signal] answered');  onCallAnswered?.call();  });
    _socket!.on('call:ended',     (_) { debugPrint('[Signal] ended');     onCallEnded?.call();     });
    _socket!.on('call:declined',  (_) { debugPrint('[Signal] declined');  onCallDeclined?.call();  });

    _socket!.onDisconnect((_) {
      _connecting = false;
      debugPrint('[Signal] disconnected');
    });

    _socket!.connect();
  }

  // ─── EMIT ───
  void notifyIncoming({
    required String toUserId,
    required String fromUserId,
    required String fromUsername,
    required String fromAvatar,
    required bool   isVideo,
  }) {
    _socket?.emit('call:offer', {
      'to':           toUserId,
      'from':         fromUserId,
      'fromUsername': fromUsername,
      'fromAvatar':   fromAvatar,
      'callType':     isVideo ? 'video' : 'voice',
      'offer':        {},
    });
    debugPrint('[Signal] offer sent to $toUserId');
  }

  void sendAnswered(String toUserId) {
    _socket?.emit('call:answer', {'to': toUserId, 'answer': {}});
    debugPrint('[Signal] answer sent to $toUserId');
  }

  void sendDecline(String toUserId) {
    _socket?.emit('call:decline', {'to': toUserId});
    debugPrint('[Signal] decline sent to $toUserId');
  }

  void sendEnd(String toUserId) {
    _socket?.emit('call:end', {'to': toUserId});
    debugPrint('[Signal] end sent to $toUserId');
  }
}
