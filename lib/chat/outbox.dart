import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_repository.dart';

// ══════════════════════════════════════════════════════════════════
//  Навбати паёмҳои нафиристода.
//
//  ⚠️ Чаро ин лозим шуд.
//
//  Ҳангоми нокомии фиристодан код паёмро ҳамчун `MessageStatus.sent`
//  нишон медод — яъне барнома ба корбар ДУРӮҒ мегуфт. Паём ҳеҷ гоҳ
//  нарасида буд, вале дар экран «фиристода шуд» менамуд. Ин аз гум
//  кардани паём БАДТАР аст: корбар боварӣ дорад, ки хабараш расид.
//
//  Акнун паёми нофиристода дар диск нигоҳ дошта мешавад ва ҳангоми
//  баргаштани интернет худаш фиристода мешавад.
//
//  ⚠️ Такрор набояд паёми дуюм созад. Ҳар паём шиносаи маҳаллӣ
//  (`clientId`) дорад; агар дархости аввал ба сервер расида бошад,
//  вале ҷавоб гум шуда бошад, сервер бо ҳамон шиноса паёми МАВҶУДро
//  бармегардонад, на паёми нав.
// ══════════════════════════════════════════════════════════════════

class PendingMessage {
  final String clientId;
  final String toUserId;
  final String chatId;
  final String text;
  final String? replyToId;
  final String? mediaUrl;
  final String? mediaType;
  final bool viewOnce;
  final int attempts;
  final int createdAtMs;

  const PendingMessage({
    required this.clientId,
    required this.toUserId,
    required this.chatId,
    required this.text,
    this.replyToId,
    this.mediaUrl,
    this.mediaType,
    this.viewOnce = false,
    this.attempts = 0,
    required this.createdAtMs,
  });

  PendingMessage bumpAttempt() => PendingMessage(
        clientId: clientId,
        toUserId: toUserId,
        chatId: chatId,
        text: text,
        replyToId: replyToId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        viewOnce: viewOnce,
        attempts: attempts + 1,
        createdAtMs: createdAtMs,
      );

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'toUserId': toUserId,
        'chatId': chatId,
        'text': text,
        'replyToId': replyToId,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'viewOnce': viewOnce,
        'attempts': attempts,
        'createdAtMs': createdAtMs,
      };

  static PendingMessage? fromJson(Map<String, dynamic> j) {
    final id = (j['clientId'] ?? '').toString();
    if (id.isEmpty) return null;
    return PendingMessage(
      clientId: id,
      toUserId: (j['toUserId'] ?? '').toString(),
      chatId: (j['chatId'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      replyToId: j['replyToId'] as String?,
      mediaUrl: j['mediaUrl'] as String?,
      mediaType: j['mediaType'] as String?,
      viewOnce: j['viewOnce'] == true,
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      createdAtMs: (j['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class Outbox {
  Outbox._();
  static final Outbox instance = Outbox._();

  static const _key = 'chat_outbox_v1';

  /// Баъди ин қадар кӯшиш паём партофта мешавад.
  ///
  /// Бе ҳад паёми ҳамеша ноком (масалан ба корбари ҳазфшуда) абадан
  /// дар навбат мемонд ва ҳар бор шабакаро банд мекард.
  static const _maxAttempts = 8;

  /// Синну соли ҳадди аксар. Паёми хеле кӯҳна маъно надорад.
  static const _maxAge = Duration(days: 3);

  final ChatRepository _repo = ChatRepository();
  final _rand = Random();

  /// Ҳангоми фиристодани муваффақ — то экран паёмро нав кунад.
  final StreamController<String> _sent = StreamController<String>.broadcast();
  Stream<String> get onSent => _sent.stream;

  StreamSubscription? _netSub;
  Timer? _retryTimer;
  bool _draining = false;

  /// Шиносаи нави маҳаллӣ.
  String newClientId() {
    final ms = DateTime.now().microsecondsSinceEpoch;
    return '$ms-${_rand.nextInt(1 << 32)}';
  }

  /// Ба навбат гӯш медиҳад: ҳангоми баргаштани интернет худаш
  /// мефиристад.
  void start() {
    _netSub ??= Connectivity().onConnectivityChanged.listen((r) {
      final online = r.any((e) => e != ConnectivityResult.none);
      if (online) drain();
    });
    // Барнома метавонад бо паёмҳои навбатӣ кушода шавад.
    drain();
  }

  void dispose() {
    _netSub?.cancel();
    _netSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<List<PendingMessage>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      final out = <PendingMessage>[];
      for (final s in raw) {
        try {
          final m = PendingMessage.fromJson(
              jsonDecode(s) as Map<String, dynamic>);
          if (m != null) out.add(m);
        } catch (_) {
          // Сабти вайрон тамоми навбатро вайрон накунад.
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<PendingMessage> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, list.map((m) => jsonEncode(m.toJson())).toList());
    } catch (_) {}
  }

  /// Паёмро ба навбат мегузорад.
  Future<void> add(PendingMessage m) async {
    final list = await all();
    // Ҳамон шиноса ду бор наояд.
    if (list.any((e) => e.clientId == m.clientId)) return;
    list.add(m);
    await _save(list);
  }

  Future<void> remove(String clientId) async {
    final list = await all();
    list.removeWhere((e) => e.clientId == clientId);
    await _save(list);
  }

  /// Паёмҳои як сӯҳбат — то экран онҳоро нишон диҳад.
  Future<List<PendingMessage>> forChat(String chatId) async {
    if (chatId.isEmpty) return [];
    final list = await all();
    return list.where((e) => e.chatId == chatId).toList();
  }

  /// Ҳамаи навбатро мефиристад.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final list = await all();
      if (list.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final keep = <PendingMessage>[];

      for (final m in list) {
        // Хеле кӯҳна ё хеле бисёр кӯшиш — партофта мешавад.
        final age = Duration(milliseconds: now - m.createdAtMs);
        if (m.attempts >= _maxAttempts || age > _maxAge) {
          debugPrint('[Outbox] партофта шуд: ${m.clientId}');
          continue;
        }
        try {
          await _repo.sendMessage(
            toUserId: m.toUserId,
            text: m.text,
            replyToId: m.replyToId,
            chatId: m.chatId,
            mediaUrl: m.mediaUrl,
            mediaType: m.mediaType,
            viewOnce: m.viewOnce,
            clientId: m.clientId,
          );
          _sent.add(m.clientId);
        } catch (e) {
          debugPrint('[Outbox] ${m.clientId}: $e');
          keep.add(m.bumpAttempt());
        }
      }

      await _save(keep);

      // Агар чизе монда бошад, баъдтар боз кӯшиш мекунем. Фосила
      // меафзояд, то шабакаи суст бо такрор банд нашавад.
      _retryTimer?.cancel();
      if (keep.isNotEmpty) {
        final worst = keep.map((e) => e.attempts).reduce(max);
        final secs = min(300, 5 * (1 << min(worst, 6)));
        _retryTimer = Timer(Duration(seconds: secs), drain);
      }
    } finally {
      _draining = false;
    }
  }
}
