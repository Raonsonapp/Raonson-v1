// lib/core/sso/tajikshop_sso.dart
// ════════════════════════════════════════════════════════════════════
//  Як ҳисоб барои Raonson ва TajikShop.
//
//  TajikShop → Raonson:  `raonson://sso?code=…`
//    Код ТАНҲО ба сервери мо меравад (POST /auth/sso/tajikshop). Калиди
//    шарики TajikShop дар сервер аст — барнома онро ҳеҷ гоҳ намебинад,
//    бинобар ин код ба TajikShop бевосита фиристода намешавад.
//
//  Raonson → TajikShop:  POST /sso/tajikshop/handoff → `tajikshop://sso?code=…`
//    Агар TajikShop насб набошад — Play Store.
//
//  Ин файл: таҷзияи линк, қабати API (транспорт иваз мешавад — барои
//  тест), ҳолати «пайвандро баъди вуруд тасдиқ кунед» ва кушодани
//  барномаи TajikShop.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../i18n/strings.dart';

class TajikshopSsoEndpoints {
  static const signIn = '/auth/sso/tajikshop';
  static const link = '/auth/sso/tajikshop/link';
  static const status = '/sso/tajikshop/status';
  static const unlink = '/sso/tajikshop/link';
  static const handoff = '/sso/tajikshop/handoff';
}

/// Ҷавоби хоми сервер.
class SsoResponse {
  final int status;
  final Map<String, dynamic> body;
  const SsoResponse(this.status, this.body);
}

typedef SsoTransport = Future<SsoResponse> Function(
    String method, String path, Map<String, dynamic>? body);

Future<SsoResponse> _apiTransport(
    String method, String path, Map<String, dynamic>? body) async {
  final c = ApiClient.instance;
  // POST бе такрор ва бо timeout-и дароз: сервер то 15 с ба TajikShop
  // интизор мешавад ва код якдафъаина аст — такрор онро месӯзонд.
  final res = switch (method) {
    'GET' => await c.get(path),
    'DELETE' => await c.delete(path),
    _ => await c.postLong(path, body: body),
  };
  Map<String, dynamic> j = {};
  try {
    final d = jsonDecode(res.body);
    if (d is Map<String, dynamic>) j = d;
  } catch (_) {}
  return SsoResponse(res.statusCode, j);
}

/// Ҳисоби TajikShop (ном ва почта аз сервер ПӮШИДА меоянд).
class TajikshopAccount {
  final String name;
  final String email;
  final DateTime? linkedAt;
  const TajikshopAccount({this.name = '', this.email = '', this.linkedAt});

  factory TajikshopAccount.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return TajikshopAccount(
      name: (m['name'] ?? '').toString(),
      email: (m['email'] ?? '').toString(),
      linkedAt: DateTime.tryParse((m['linkedAt'] ?? '').toString()),
    );
  }
}

enum SsoOutcome { signedIn, linked, confirmLink, linkRequired, failed }

class SsoResult {
  final SsoOutcome outcome;
  final int status;
  final Map<String, dynamic> body;
  const SsoResult(this.outcome, this.status, this.body);

  bool get needsProfileSetup => body['needsProfileSetup'] == true;
  bool get created => body['status'] == 'created';
  String get pendingToken => (body['pendingToken'] ?? '').toString();
  int get expiresIn => (body['expiresIn'] as num?)?.toInt() ?? 600;
  String get maskedEmail => (body['email'] ?? '').toString();
  String get code => (body['code'] ?? '').toString();
  TajikshopAccount get account => TajikshopAccount.fromJson(body['tajikshop']);

  /// Матни хато ба забони барнома (рамзи сервер → tr), вагарна матни сервер.
  String get message {
    switch (code) {
      case 'invalid_code':
        return tr('sso.err.invalidCode');
      case 'sso_not_configured':
        return tr('sso.notConfigured');
      case 'provider_unavailable':
        return tr('sso.err.unavailable');
      case 'linked_other':
        return tr('sso.err.linkedOther');
      case 'already_linked':
        return tr('sso.err.alreadyLinked');
      case 'link_expired':
        return tr('sso.err.linkExpired');
      case 'banned':
        return tr('sso.err.banned');
      case 'password_required':
        return tr('sso.err.passwordRequired');
      case 'network':
        return tr('account.err.network');
    }
    final m = (body['message'] ?? '').toString();
    return m.isNotEmpty ? m : tr('sso.error');
  }

  static SsoResult parse(SsoResponse r) {
    final b = r.body;
    if (r.status == 409 && b['code'] == 'link_required') {
      return SsoResult(SsoOutcome.linkRequired, r.status, b);
    }
    if (r.status >= 200 && r.status < 300) {
      switch (b['status']) {
        case 'confirm_link':
          return SsoResult(SsoOutcome.confirmLink, r.status, b);
        case 'linked':
          return SsoResult(SsoOutcome.linked, r.status, b);
      }
      if ((b['accessToken'] ?? '').toString().isNotEmpty) {
        return SsoResult(SsoOutcome.signedIn, r.status, b);
      }
      if (b['linked'] == true) return SsoResult(SsoOutcome.linked, r.status, b);
    }
    return SsoResult(SsoOutcome.failed, r.status, b);
  }

  static const network =
      SsoResult(SsoOutcome.failed, 0, {'code': 'network'});
}

/// Ҳолати пайванд дар «Ҳисобҳои пайвастшуда».
class TajikshopStatus {
  final bool configured;
  final bool linked;
  final bool hasPassword;
  final bool canOpenSignedIn;
  final String fallback;
  final TajikshopAccount? account;
  const TajikshopStatus({
    this.configured = false,
    this.linked = false,
    this.hasPassword = true,
    this.canOpenSignedIn = false,
    this.fallback = TajikshopSso.playStore,
    this.account,
  });

  factory TajikshopStatus.fromJson(Map<String, dynamic> j) => TajikshopStatus(
        configured: j['configured'] == true,
        linked: j['linked'] == true,
        hasPassword: j['hasPassword'] != false,
        canOpenSignedIn: j['canOpenSignedIn'] == true,
        fallback: (j['fallback'] ?? '').toString().startsWith('https://')
            ? j['fallback'].toString()
            : TajikshopSso.playStore,
        account: j['tajikshop'] is Map
            ? TajikshopAccount.fromJson(j['tajikshop'])
            : null,
      );
}

/// Ҷавоби «TajikShop-ро кушоед».
class TajikshopHandoff {
  final bool linked;
  final bool signedIn; // бо код (корбар дар TajikShop фавран ворид)
  final String deepLink;
  final String fallback;
  final String reason;
  const TajikshopHandoff({
    required this.linked,
    required this.signedIn,
    required this.deepLink,
    required this.fallback,
    this.reason = '',
  });

  factory TajikshopHandoff.fromJson(Map<String, dynamic> j) {
    var dl = (j['deep_link'] ?? '').toString();
    // Танҳо схемаи TajikShop — ҷавоби сервер ҳеҷ гоҳ линки дигарро
    // кушода наметавонад.
    if (!dl.startsWith('${TajikshopSso.tajikshopScheme}://')) {
      dl = '${TajikshopSso.tajikshopScheme}://';
    }
    final fb = (j['fallback'] ?? '').toString();
    return TajikshopHandoff(
      linked: j['linked'] == true,
      signedIn: j['handoff'] == true,
      deepLink: dl,
      fallback: fb.startsWith('https://') ? fb : TajikshopSso.playStore,
      reason: (j['reason'] ?? '').toString(),
    );
  }

  static const plain = TajikshopHandoff(
      linked: false,
      signedIn: false,
      deepLink: '${TajikshopSso.tajikshopScheme}://',
      fallback: TajikshopSso.playStore,
      reason: 'offline');
}

class TajikshopSsoRepository {
  TajikshopSsoRepository({SsoTransport? transport})
      : _t = transport ?? _apiTransport;
  final SsoTransport _t;

  Future<SsoResponse> _call(String m, String p, [Map<String, dynamic>? b]) async {
    try {
      return await _t(m, p, b);
    } on SocketException {
      return const SsoResponse(0, {'code': 'network'});
    } on TimeoutException {
      return const SsoResponse(0, {'code': 'network'});
    } catch (_) {
      return const SsoResponse(0, {'code': 'network'});
    }
  }

  /// Коди TajikShop → сессияи Raonson (ё пайванд, агар [link]).
  Future<SsoResult> signIn(String code, {bool link = false}) async =>
      SsoResult.parse(await _call('POST', TajikshopSsoEndpoints.signIn,
          {'code': code, if (link) 'link': true}));

  /// Тасдиқи пайванд баъди вуруд (token аз link_required / confirm_link).
  Future<SsoResult> confirmLink(String pendingToken) async =>
      SsoResult.parse(await _call('POST', TajikshopSsoEndpoints.link,
          {'pendingToken': pendingToken}));

  Future<TajikshopStatus?> status() async {
    final r = await _call('GET', TajikshopSsoEndpoints.status);
    if (r.status != 200) return null;
    return TajikshopStatus.fromJson(r.body);
  }

  Future<SsoResult> unlink() async {
    final r = await _call('DELETE', TajikshopSsoEndpoints.unlink);
    if (r.status == 200) {
      return SsoResult(SsoOutcome.linked, r.status, {...r.body, 'linked': false});
    }
    return SsoResult(SsoOutcome.failed, r.status, r.body);
  }

  Future<TajikshopHandoff> handoff() async {
    final r = await _call('POST', TajikshopSsoEndpoints.handoff);
    if (r.status != 200) return TajikshopHandoff.plain;
    return TajikshopHandoff.fromJson(r.body);
  }
}

/// Пайванде, ки баъди вуруд бо рамзи Raonson тасдиқ мешавад.
class PendingTajikshopLink {
  final String token;
  final String maskedEmail;
  final DateTime expiresAt;
  const PendingTajikshopLink(this.token, this.maskedEmail, this.expiresAt);
  bool get expired => DateTime.now().isAfter(expiresAt);
}

typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> _defaultOpen(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false; // барнома насб нашудааст
  }
}

class TajikshopSso {
  TajikshopSso._();
  static final TajikshopSso instance = TajikshopSso._();

  static const raonsonScheme = 'raonson';
  static const tajikshopScheme = 'tajikshop';
  static const playStore =
      'https://play.google.com/store/apps/details?id=com.tajikshop.app';

  /// Код: base64url, 16…64 аломат (TajikShop 43 медиҳад).
  static final _codeRe = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  /// `raonson://sso?code=…` → код; ҳар линки дигар → null.
  ///
  /// Шакли `/sso?code=…` ҳам қабул мешавад — Flutter вобаста ба платформа
  /// схема ва host-ро метавонад партояд.
  static String? codeFromUri(Uri uri) {
    final isSso = (uri.scheme == raonsonScheme && uri.host == 'sso') ||
        (uri.scheme.isEmpty && uri.host.isEmpty && uri.path == '/sso');
    if (!isSso) return null;
    final code = (uri.queryParameters['code'] ?? '').trim();
    return _codeRe.hasMatch(code) ? code : null;
  }

  static String? codeFromRoute(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    return uri == null ? null : codeFromUri(uri);
  }

  TajikshopSsoRepository repo = TajikshopSsoRepository();

  /// Кушодани линкҳо — дар тест иваз мешавад.
  UrlOpener opener = _defaultOpen;

  // ── Кодҳои коркардшуда ──
  //
  // Оғози сард бо линк: `restartApp()` (ивази аккаунт) дарахтро аз нав
  // месозад ва ҳамон линк боз ҳамчун роҳи аввал меояд. Коди сӯхта набояд
  // экрани «Код нодуруст»-ро дубора нишон диҳад.
  final Set<String> _handled = {};
  bool wasHandled(String code) => _handled.contains(code);
  void markHandled(String code) => _handled.add(code);

  // ── «Пайвандро баъди вуруд тасдиқ кунед» ──
  final ValueNotifier<PendingTajikshopLink?> pendingLink = ValueNotifier(null);

  void setPending(String token, String maskedEmail, int expiresIn) {
    pendingLink.value = PendingTajikshopLink(token, maskedEmail,
        DateTime.now().add(Duration(seconds: expiresIn.clamp(30, 600))));
  }

  void clearPending() => pendingLink.value = null;

  /// Баъди вуруди муваффақ: агар пайванди интизор бошад — тасдиқ.
  /// null — чизе интизор набуд.
  Future<SsoResult?> completePendingLink() async {
    final p = pendingLink.value;
    if (p == null) return null;
    pendingLink.value = null;
    if (p.expired) {
      return const SsoResult(
          SsoOutcome.failed, 401, {'code': 'link_expired'});
    }
    final r = await repo.confirmLink(p.token);
    if (r.outcome == SsoOutcome.linked) linkChanged.value++;
    return r;
  }

  /// Ҳар тағйири пайванд — экрани «Ҳисобҳои пайвастшуда» нав мешавад.
  final ValueNotifier<int> linkChanged = ValueNotifier(0);

  // ── Нияти «Пайваст кардан» ──
  //
  // Корбар дар Танзимот «Пайваст кардан»-ро зад ва ба TajikShop рафт.
  // Барнома дар ин вақт метавонад аз хотира бароварда шавад, пас ният
  // дар SharedPreferences (10 дақ) нигоҳ дошта мешавад.
  static const _intentKey = 'sso_tajikshop_link_intent';
  static const intentTtl = Duration(minutes: 10);

  Future<void> setLinkIntent() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_intentKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Як бор: true агар ният дар 10 дақиқаи охир гузошта шуда бошад.
  Future<bool> consumeLinkIntent() async {
    try {
      final p = await SharedPreferences.getInstance();
      final at = p.getInt(_intentKey);
      if (at == null) return false;
      await p.remove(_intentKey);
      return DateTime.now().millisecondsSinceEpoch - at <
          intentTtl.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  // ── Кушодани TajikShop ──

  /// deep link → агар насб набошад, fallback (Play Store).
  Future<bool> openLink(String deepLink, String fallback) async {
    if (await opener(Uri.parse(deepLink))) return true;
    if (fallback.startsWith('https://')) {
      return opener(Uri.parse(fallback));
    }
    return false;
  }

  /// TajikShop бе ворид (`tajikshop://` ё Play Store).
  Future<bool> openPlain() => openLink('$tajikshopScheme://', playStore);

  /// TajikShop бо ҳамин ҳисоб, агар пайваст бошад. Натиҷаро бармегардонад,
  /// то экран «пайваст нест»-ро нишон диҳад.
  Future<TajikshopHandoff> handoff() => repo.handoff();

  @visibleForTesting
  void debugReset() {
    _handled.clear();
    pendingLink.value = null;
    repo = TajikshopSsoRepository();
    opener = _defaultOpen;
  }
}
