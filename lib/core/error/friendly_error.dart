// lib/core/error/friendly_error.dart
//
// Хатои техникиро ба матни фаҳмо барои корбар табдил медиҳад.
//
// ⚠️ Чаро лозим шуд: дар профил ҳангоми интернети суст корбар бо ранги
// сурх `TimeoutException after 0:00:08.000000: Future not completed`
// медид. Матни хатои Dart/HTTP ҳеҷ гоҳ ба экран намебарояд — ҳама ҷо
// [friendlyError] истифода мешавад.
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../i18n/strings.dart';

/// Навъи хато — барои қарор: баннер, экрани хато ё матни сервер.
enum NetErrorKind {
  /// Интернет нест (DNS, пайваст рад шуд, шабака дастрас нест).
  offline,

  /// Сервер дар вақташ ҷавоб надод (интернети суст ё cold start).
  timeout,

  /// Сервер 5xx ё ҷавоби вайрон (HTML ба ҷои JSON) баргардонд.
  server,

  /// Сервер дархостро рад кард (4xx).
  rejected,

  /// Дигар.
  unknown,
}

NetErrorKind classifyError(Object? e) {
  if (e is TimeoutException) return NetErrorKind.timeout;
  if (e is SocketException || e is HandshakeException) {
    return NetErrorKind.offline;
  }
  if (e is http.ClientException) {
    final m = e.message.toLowerCase();
    if (m.contains('timed out') || m.contains('timeout')) {
      return NetErrorKind.timeout;
    }
    return NetErrorKind.offline;
  }
  if (e is HttpException) return NetErrorKind.offline;
  if (e is ApiException) {
    return e.status >= 500 ? NetErrorKind.server : NetErrorKind.rejected;
  }
  // Space-и хобида баъзан HTML бармегардонад → jsonDecode меафтад.
  if (e is FormatException) return NetErrorKind.server;
  final s = e?.toString() ?? '';
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused') ||
      s.contains('Connection reset') ||
      s.contains('Connection closed')) {
    return NetErrorKind.offline;
  }
  if (s.contains('TimeoutException')) return NetErrorKind.timeout;
  if (RegExp(r'\b5\d\d\b').hasMatch(s) && s.contains('Server')) {
    return NetErrorKind.server;
  }
  return NetErrorKind.unknown;
}

/// Хато аз шабака аст (на хатои мантиқ) — пас кэш нишон додан ба ҷост.
bool isNetworkError(Object? e) {
  final k = classifyError(e);
  return k == NetErrorKind.offline ||
      k == NetErrorKind.timeout ||
      k == NetErrorKind.server;
}

/// Матни кӯтоҳ ва фаҳмо барои корбар.
///
/// [hasCache] — дар экран маълумоти охирин (кэш) нишон дода шудааст;
/// пас ҳангоми пайвасти суст мегӯем, ки маълумоти охирин аст.
String friendlyError(Object? e, {bool hasCache = false}) {
  switch (classifyError(e)) {
    case NetErrorKind.offline:
      return hasCache ? tr('net.offlineCached') : tr('net.offline');
    case NetErrorKind.timeout:
      return hasCache ? tr('net.slowCached') : tr('net.serverNoResponse');
    case NetErrorKind.server:
      return tr('net.serverNoResponse');
    case NetErrorKind.rejected:
      final m = (e as ApiException).message;
      return (m != null && _looksHuman(m)) ? m : tr('common.failedRetry');
    case NetErrorKind.unknown:
      // Хатои барномасозӣ (TypeError, StateError…) ҳеҷ гоҳ нишон дода
      // намешавад.
      if (e is Error) return tr('common.failedRetry');
      // `throw Exception('Корбар ёфт нашуд')` — матни барои корбар
      // навишташуда нигоҳ дошта мешавад; матни техникӣ — не.
      final raw = (e?.toString() ?? '').trim();
      final m = raw.startsWith('Exception:') ? raw.substring(10).trim() : raw;
      return _looksHuman(m) ? m : tr('common.failedRetry');
  }
}

/// Матни одамӣ: кӯтоҳ ва бе нишонаҳои стек/синфҳои Dart (масалан
/// хабари `{"message": "..."}`-и сервер ё `Exception('Корбар ёфт нашуд')`).
bool _looksHuman(String m) {
  if (m.trim().isEmpty || m.length > 140) return false;
  const tech = [
    'Exception', 'Error', 'Future', '0:00:', 'http', '#0', '{', '<',
    'subtype', 'Instance of', 'dart:', 'Socket', 'Timeout', 'Null',
  ];
  return !tech.any(m.contains);
}
