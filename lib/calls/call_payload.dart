// lib/calls/call_payload.dart
// ════════════════════════════════════════════════════════════════════
//  Занги воридотӣ — як шакл барои ҳар се манбаъ:
//    • push-и data-only аз сервер (backend/notify/call.go → CallData)
//    • ҳодисаи сокети `call:incoming`
//    • `extra`-и flutter_callkit_incoming (ҳангоми қабул/рад)
//
//  Мантиқи тоза, бе плагин — то бе дастгоҳ санҷида шавад.
// ════════════════════════════════════════════════════════════════════
import 'package:uuid/uuid.dart';

/// Шиносаи намуди push-и занг (бо backend/notify/kind.go IncomingCall).
const kIncomingCallType = 'incoming_call';

class IncomingCall {
  /// UUID-и занг. flutter_callkit_incoming ТАНҲО UUID қабул мекунад.
  final String callId;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final bool isVideo;

  /// Вақти сервер ҳангоми фиристодан (ms). 0 = номаълум (сокет).
  final int sentAtMs;

  const IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.isVideo,
    this.sentAtMs = 0,
  });

  String get callType => isVideo ? 'video' : 'voice';

  /// Занги ин қадар кӯҳна дигар занг намезанад: сервер TTL-и 30с
  /// медиҳад, зангзананда пас аз 60с қатъ мекунад. Каме захира барои
  /// фарқи соати телефон ва сервер.
  static const maxAge = Duration(seconds: 60);

  /// Оё push дер расид (масалан телефон 10 дақиқа бе шабака буд)?
  bool isStale(DateTime now) {
    if (sentAtMs <= 0) return false;
    final age = now.millisecondsSinceEpoch - sentAtMs;
    return age > maxAge.inMilliseconds;
  }

  /// Аз data-и push. null — агар ин push-и занг набошад ё нопурра бошад.
  static IncomingCall? fromPush(Map<String, dynamic> data) {
    if (data['type']?.toString() != kIncomingCallType) return null;
    final callerId = _s(data['callerId']).isNotEmpty
        ? _s(data['callerId'])
        : _s(data['id']);
    if (callerId.isEmpty) return null;
    final id = _s(data['callId']);
    return IncomingCall(
      callId: isUuid(id) ? id : uuidFor(callerId, _s(data['sentAt'])),
      callerId: callerId,
      callerName: _s(data['callerName']),
      callerAvatar: _s(data['callerAvatar']),
      isVideo: _s(data['callType']).toLowerCase() == 'video',
      sentAtMs: int.tryParse(_s(data['sentAt'])) ?? 0,
    );
  }

  /// Аз ҳодисаи сокети `call:incoming`. Сокет callId надорад — UUID
  /// аз зангзананда ва вақт сохта мешавад.
  static IncomingCall? fromSocket(dynamic data, {DateTime? now}) {
    if (data is! Map) return null;
    final callerId = _s(data['from']);
    if (callerId.isEmpty) return null;
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return IncomingCall(
      callId: uuidFor(callerId, '$t'),
      callerId: callerId,
      callerName: _s(data['fromUsername']),
      callerAvatar: _s(data['fromAvatar']),
      isVideo: _s(data['callType']).toLowerCase() == 'video',
    );
  }

  /// Барои `extra`-и callkit — баъди қабул/рад ҳамин бармегардад.
  Map<String, dynamic> toExtra() => {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'callType': callType,
        'sentAt': '$sentAtMs',
      };

  /// Аз `extra`-и callkit (ё ҳар харитаи [toExtra]).
  static IncomingCall? fromExtra(Map<dynamic, dynamic>? extra,
      {String? callId}) {
    if (extra == null) return null;
    final callerId = _s(extra['callerId']);
    if (callerId.isEmpty) return null;
    final id = _s(callId).isNotEmpty ? _s(callId) : _s(extra['callId']);
    return IncomingCall(
      callId: id,
      callerId: callerId,
      callerName: _s(extra['callerName']),
      callerAvatar: _s(extra['callerAvatar']),
      isVideo: _s(extra['callType']).toLowerCase() == 'video',
      sentAtMs: int.tryParse(_s(extra['sentAt'])) ?? 0,
    );
  }

  static String _s(Object? v) => v?.toString().trim() ?? '';

  static final _uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static bool isUuid(String s) => _uuidRe.hasMatch(s);

  /// UUID-и муайян (v5) аз сатрҳо.
  ///
  /// Муайян аст, то ҳамон занг аз ду манбаъ ҳамон шиносаро гирад.
  static String uuidFor(String a, String b) =>
      const Uuid().v5(Namespace.url.value, 'raonson-call:$a|$b');
}
