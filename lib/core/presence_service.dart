import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'storage/token_storage.dart';

class PresenceInfo {
  final bool      isOnline;
  final DateTime? lastSeen;
  const PresenceInfo({required this.isOnline, this.lastSeen});
}

class PresenceService extends ChangeNotifier {
  static final PresenceService _i = PresenceService._();
  factory PresenceService() => _i;
  PresenceService._();

  io.Socket? _socket;
  bool _ready = false;

  // userId → PresenceInfo
  final Map<String, PresenceInfo> _status = {};

  // Queue of userIds to check once connected
  final List<String> _pending = [];

  bool   isOnline(String userId) => _status[userId]?.isOnline ?? false;

  String lastSeenLabel(String userId) {
    final p = _status[userId];
    if (p == null)      return '';
    if (p.isOnline)     return 'online';
    final ls = p.lastSeen;
    if (ls == null)     return 'offline';
    final diff = DateTime.now().difference(ls);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    == 1)  return 'yesterday';
    return '${diff.inDays}d ago';
  }

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    if (_socket != null) {
      // Already connecting — wait for ready
      return;
    }

    _socket = io.io(
      'https://raonson-v1.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) async {
      _ready = true;
      debugPrint('[Presence] connected');

      // Register self as online
      final uid = await TokenStorage.getUserId();
      if (uid != null && uid.isNotEmpty) {
        _socket!.emit('presence:online', {'userId': uid});
      }

      // Flush pending checks
      for (final id in _pending) {
        _socket!.emit('presence:check', {'userId': id});
      }
      _pending.clear();
    });

    // Server broadcasts when any user goes online/offline
    _socket!.on('presence:update', (data) {
      final userId = data['userId']?.toString();
      if (userId == null) return;
      final online = data['status'] == 'online';
      final ls     = data['lastSeen'];
      _status[userId] = PresenceInfo(
        isOnline: online,
        lastSeen: ls != null ? DateTime.tryParse(ls.toString()) : null,
      );
      debugPrint('[Presence] update: $userId → ${online ? "online" : "offline"}');
      notifyListeners();
    });

    // Response to presence:check
    _socket!.on('presence:checked', (data) {
      final userId = data['userId']?.toString();
      if (userId == null) return;
      final online = data['isOnline'] as bool? ?? false;
      final ls     = data['lastSeen'];
      _status[userId] = PresenceInfo(
        isOnline: online,
        lastSeen: ls != null ? DateTime.tryParse(ls.toString()) : null,
      );
      debugPrint('[Presence] checked: $userId → ${online ? "online" : "offline"} | lastSeen=$ls');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _ready = false;
      debugPrint('[Presence] disconnected');
    });

    _socket!.connect();
  }

  /// Check a user's status.
  /// If socket not ready yet, queues the request.
  void checkUser(String userId) {
    if (_ready) {
      _socket!.emit('presence:check', {'userId': userId});
    } else {
      if (!_pending.contains(userId)) _pending.add(userId);
    }
  }
}
