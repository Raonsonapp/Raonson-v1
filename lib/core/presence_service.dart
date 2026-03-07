import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'storage/token_storage.dart';

class PresenceInfo {
  final bool     isOnline;
  final DateTime? lastSeen;
  const PresenceInfo({required this.isOnline, this.lastSeen});
}

/// Singleton — tracks online/offline status of users via socket.
class PresenceService extends ChangeNotifier {
  static final PresenceService _i = PresenceService._();
  factory PresenceService() => _i;
  PresenceService._();

  io.Socket? _socket;
  bool _connecting = false;

  // userId → PresenceInfo
  final Map<String, PresenceInfo> _status = {};

  PresenceInfo? statusOf(String userId) => _status[userId];

  bool isOnline(String userId) => _status[userId]?.isOnline ?? false;

  /// Human-readable last seen string (like WhatsApp/Instagram)
  String lastSeenLabel(String userId) {
    final p = _status[userId];
    if (p == null) return '';
    if (p.isOnline) return 'online';
    final ls = p.lastSeen;
    if (ls == null) return 'offline';
    final diff = DateTime.now().difference(ls);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours   < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

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
        _socket!.emit('presence:online', {'userId': uid});
        debugPrint('[Presence] online: $uid');
      }
    });

    // Listen for any user going online/offline
    _socket!.on('presence:update', (data) {
      final userId = data['userId'] as String?;
      if (userId == null) return;
      final isOnline = data['status'] == 'online';
      final ls = data['lastSeen'];
      _status[userId] = PresenceInfo(
        isOnline: isOnline,
        lastSeen: ls != null ? DateTime.tryParse(ls) : null,
      );
      debugPrint('[Presence] $userId → ${isOnline ? "online" : "offline"}');
      notifyListeners();
    });

    // Response to a specific check
    _socket!.on('presence:checked', (data) {
      final userId  = data['userId'] as String?;
      final online  = data['isOnline'] as bool? ?? false;
      if (userId == null) return;
      _status[userId] = PresenceInfo(isOnline: online, lastSeen: _status[userId]?.lastSeen);
      notifyListeners();
    });

    _socket!.onDisconnect((_) => _connecting = false);
    _socket!.connect();
  }

  /// Ask server if specific user is online
  void checkUser(String userId) {
    _socket?.emit('presence:check', {'userId': userId});
  }
}
