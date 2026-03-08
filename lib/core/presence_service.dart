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

  final Map<String, PresenceInfo> _status  = {};
  final List<String>              _pending = [];

  bool isOnline(String userId) => _status[userId]?.isOnline ?? false;

  /// Тоҷикӣ: "дар сайт", "5 дақ пеш", "2 соат пеш" ...
  String lastSeenLabel(String userId) {
    final p = _status[userId];
    if (p == null)  return '';
    if (p.isOnline) return 'дар сайт';
    final ls = p.lastSeen;
    if (ls == null) return 'офлайн';
    final diff = DateTime.now().difference(ls);
    if (diff.inSeconds < 60)  return 'ҳозир буд';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} дақ пеш';
    if (diff.inHours   < 24)  return '${diff.inHours} соат пеш';
    if (diff.inDays    == 1)  return 'дирӯз буд';
    return '${diff.inDays} рӯз пеш';
  }

  Future<void> connect() async {
    if (_socket?.connected == true) return;
    if (_socket != null) return; // connecting in progress

    _socket = io.io(
      'https://raonson-v1.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) async {
      _ready = true;
      debugPrint('[Presence] пайваст шуд');
      final uid = await TokenStorage.getUserId();
      if (uid != null && uid.isNotEmpty) {
        _socket!.emit('presence:online', {'userId': uid});
        debugPrint('[Presence] онлайн: $uid');
      }
      // Flush pending checks
      for (final id in List.of(_pending)) {
        _socket!.emit('presence:check', {'userId': id});
      }
      _pending.clear();
    });

    _socket!.on('presence:update', (data) {
      final userId = data['userId']?.toString();
      if (userId == null) return;
      final online = data['status'] == 'online';
      final ls     = data['lastSeen'];
      _status[userId] = PresenceInfo(
        isOnline: online,
        lastSeen: ls != null ? DateTime.tryParse(ls.toString()) : null,
      );
      debugPrint('[Presence] $userId → ${online ? "онлайн" : "офлайн"}');
      notifyListeners();
    });

    _socket!.on('presence:checked', (data) {
      final userId = data['userId']?.toString();
      if (userId == null) return;
      final online = data['isOnline'] as bool? ?? false;
      final ls     = data['lastSeen'];
      _status[userId] = PresenceInfo(
        isOnline: online,
        lastSeen: ls != null ? DateTime.tryParse(ls.toString()) : null,
      );
      debugPrint('[Presence] checked: $userId → ${online ? "онлайн" : "офлайн"} ls=$ls');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _ready = false;
      debugPrint('[Presence] қатъ шуд');
    });

    _socket!.connect();
  }

  void checkUser(String userId) {
    if (userId.isEmpty) return;
    if (_ready && _socket?.connected == true) {
      _socket!.emit('presence:check', {'userId': userId});
    } else {
      if (!_pending.contains(userId)) _pending.add(userId);
    }
  }

  /// Check multiple users at once
  void checkUsers(List<String> userIds) {
    for (final id in userIds) {
      checkUser(id);
    }
  }
}
