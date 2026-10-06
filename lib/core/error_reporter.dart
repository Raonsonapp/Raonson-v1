import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api/api_client.dart';

// ══════════════════════════════════════════════════════════════════
//  Ҳисоботи хатоҳо.
//
//  Корбар «хатои сурх дар профил»-ро мебинад, вале stack trace дар
//  телефон мемонд ва ҳеҷ кас намедонист, ки кадом сатр афтод. Акнун
//  ҳар хатои Flutter (бе такрор, то 20 дар як сессия) ба сервер
//  меравад ва дар «Панели админ → Хатоҳои барнома» дида мешавад.
//
//  Хатоҳои шабака (интернет нест, расм бор нашуд) фиристода
//  намешаванд — онҳо хатои код нестанд.
// ══════════════════════════════════════════════════════════════════
class ErrorReporter {
  ErrorReporter._();

  static const appVersion = '1.2.0';
  static const _maxPerSession = 20;

  static final Set<String> _sent = {};
  static bool _sending = false;

  /// Экрани ҷорӣ (аз NavigatorObserver).
  static String currentScreen = '';

  static final NavigatorObserver observer = _ScreenObserver();

  /// Хатои шабака ё расм — хатои код нест.
  @visibleForTesting
  static bool isNoise(Object error, String text) {
    if (error is SocketException || error is TimeoutException ||
        error is HttpException || error is HandshakeException) {
      return true;
    }
    const noise = [
      'NetworkImageLoadException', 'Invalid image data', 'HTTP request failed',
      'Connection closed', 'Connection reset', 'Failed host lookup',
      'ClientException', 'No internet', 'RenderFlex overflowed',
    ];
    return noise.any(text.contains);
  }

  static void report(Object error, StackTrace? stack) {
    final text = error.toString();
    if (isNoise(error, text)) return;
    final st = (stack ?? StackTrace.current).toString();
    // Калиди такрор: матн + аввалин сатри коди худамон.
    final own = st.split('\n').firstWhere(
        (l) => l.contains('package:raonson'), orElse: () => '');
    final key = '$text|$own';
    if (_sent.contains(key) || _sent.length >= _maxPerSession) return;
    _sent.add(key);
    if (_sending) return; // хатои худи фиристодан — давр намезанем
    _sending = true;
    ApiClient.instance.post('/client-errors', body: {
      'message': text.length > 500 ? text.substring(0, 500) : text,
      'stack': st.length > 4000 ? st.substring(0, 4000) : st,
      'screen': currentScreen,
      'appVersion': appVersion,
      'platform': defaultTargetPlatform.name,
    }).then((_) {}, onError: (_) {}).whenComplete(() => _sending = false);
  }
}

class _ScreenObserver extends NavigatorObserver {
  void _set(Route<dynamic>? r) {
    if (r == null) return;
    ErrorReporter.currentScreen = r.settings.name ??
        r.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);
}
