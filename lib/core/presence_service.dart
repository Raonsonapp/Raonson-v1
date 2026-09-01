// lib/core/presence_service.dart
import 'package:flutter/foundation.dart';
import 'services/socket_service.dart';
import 'storage/token_storage.dart';
import 'i18n/strings.dart';

class PresenceInfo {
  final bool isOnline;
  final DateTime? lastSeen;
  const PresenceInfo({required this.isOnline, this.lastSeen});
}

class PresenceService extends ChangeNotifier {
  static final PresenceService _i = PresenceService._();
  factory PresenceService() => _i;
  PresenceService._();

  final _socket = SocketService.instance;
  bool  _ready  = false;
  final Map<String, PresenceInfo> _status  = {};
  final List<String>              _pending = [];

  bool isOnline(String userId) => _status[userId]?.isOnline ?? false;

  String lastSeenLabel(String userId) {
    final p = _status[userId];
    if (p == null)  return '';
    if (p.isOnline) return tr('presence.online');
    final ls = p.lastSeen;
    if (ls == null) return tr('presence.offline');
    final diff = DateTime.now().difference(ls);
    if (diff.inSeconds < 60)  return tr('presence.justNow');
    if (diff.inMinutes < 60)  return tr('time.minutesAgo', {'n': diff.inMinutes});
    if (diff.inHours   < 24)  return tr('time.hoursAgo', {'n': diff.inHours});
    if (diff.inDays    == 1)  return tr('presence.yesterday');
    return tr('time.daysAgo', {'n': diff.inDays});
  }

  Future<void> connect() async {
    if (_ready) return;
    await _socket.autoConnect();
    final uid = await TokenStorage.getUserId();
    if (uid != null && uid.isNotEmpty) {
      _socket.emit('presence:online', {'userId': uid});
    }
    _socket.on('presence:update', (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      if (userId == null) return;
      _status[userId] = PresenceInfo(
        isOnline: data['status'] == 'online',
        lastSeen: data['lastSeen'] != null
            ? DateTime.tryParse(data['lastSeen'].toString()) : null,
      );
      notifyListeners();
    });
    _socket.on('presence:checked', (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      if (userId == null) return;
      _status[userId] = PresenceInfo(
        isOnline: data['isOnline'] as bool? ?? false,
        lastSeen: data['lastSeen'] != null
            ? DateTime.tryParse(data['lastSeen'].toString()) : null,
      );
      notifyListeners();
    });
    _ready = true;
    for (final id in List.of(_pending)) {
      _socket.emit('presence:check', {'userId': id});
    }
    _pending.clear();
  }

  void checkUser(String userId) {
    if (userId.isEmpty) return;
    if (_ready && _socket.isConnected) {
      _socket.emit('presence:check', {'userId': userId});
    } else {
      if (!_pending.contains(userId)) _pending.add(userId);
    }
  }

  void checkUsers(List<String> ids) { for (final id in ids) { checkUser(id); } }
}
