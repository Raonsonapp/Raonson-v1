// lib/auth/password/recovery_repository.dart
//
// Барқарорсозии ҳисоб — қабати API.
//
//   lookup  → «Ин шумоед?» (номи пӯшида, акс, роҳҳои фиристодани рамз)
//   send    → рамзи 6-рақама ба канали интихобшуда
//   verify  → token-и якдафъаина (15 дақ)
//   reset   → рамзи нав + token-ҳои нав (корбар фавран ворид мешавад)
//   requestHelp → «Кӯмак лозим» (маъмурият тасдиқ мекунад)
//
// Транспорт иваз мешавад — то тестҳо бе сервер кор кунанд.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';

class RecoveryEndpoints {
  static const lookup = '/auth/recover/lookup';
  static const send = '/auth/recover/send';
  static const verify = '/auth/recover/verify';
  static const reset = '/auth/recover/reset';
  static const request = '/auth/recover/request';
  static const status = '/auth/recovery-status';
}

/// Ҷавоби хоми сервер: рамзи HTTP ва JSON.
class RecoveryResponse {
  final int status;
  final Map<String, dynamic> body;
  const RecoveryResponse(this.status, this.body);
}

typedef RecoveryTransport = Future<RecoveryResponse> Function(
    String path, Map<String, dynamic> body,
    {bool long});

Future<RecoveryResponse> _apiTransport(String path, Map<String, dynamic> body,
    {bool long = false}) async {
  // `postLong` такрор намекунад: фиристодани дубора мактуби дуюм
  // мефиристод ё token-и якдафъаинаро месӯзонд.
  final res = long
      ? await ApiClient.instance.postLong(path, body: body)
      : await ApiClient.instance.post(path, body: body);
  Map<String, dynamic> j = {};
  try {
    final d = jsonDecode(res.body);
    if (d is Map<String, dynamic>) j = d;
  } catch (_) {}
  return RecoveryResponse(res.statusCode, j);
}

class RecoveryChannel {
  final String type; // email | sms | telegram | whatsapp
  final String to; // пӯшида: e***n@gmail.com
  const RecoveryChannel(this.type, this.to);

  String get label => tr('recover.channel.$type');
}

class RecoveryLookup {
  final bool found;
  final bool needUsername;
  final String maskedUsername;
  final String avatar;
  final List<RecoveryChannel> channels;
  final String message;

  const RecoveryLookup({
    required this.found,
    required this.needUsername,
    this.maskedUsername = '',
    this.avatar = '',
    this.channels = const [],
    this.message = '',
  });

  factory RecoveryLookup.fromJson(Map<String, dynamic> j) {
    final acc = j['account'] is Map ? j['account'] as Map : const {};
    return RecoveryLookup(
      found: j['found'] == true,
      needUsername: j['needUsername'] == true,
      maskedUsername: (acc['username'] ?? '').toString(),
      avatar: (acc['avatar'] ?? '').toString(),
      channels: ((j['channels'] as List?) ?? const [])
          .whereType<Map>()
          .map((c) => RecoveryChannel(
              (c['type'] ?? '').toString(), (c['to'] ?? '').toString()))
          .where((c) => c.type.isNotEmpty)
          .toList(),
      message: (j['message'] ?? '').toString(),
    );
  }
}

class RecoverySent {
  final String channel;
  final String to;
  final int resendIn;
  final int expiresIn;

  /// Танҳо дар сервери санҷишӣ (OTP_ECHO). Дар продакшн ҳеҷ гоҳ нест.
  final String? devOtp;

  const RecoverySent({
    required this.channel,
    required this.to,
    this.resendIn = 60,
    this.expiresIn = 600,
    this.devOtp,
  });
}

/// Хатои фаҳмо барои корбар. [code] — аз сервер (invalid_code, expired,
/// locked, cooldown, need_username, invalid_token, weak_password, …) ё
/// `network`.
class RecoveryException implements Exception {
  final String code;
  final String message;
  final int status;
  final int? retryAfter;
  final int? attemptsLeft;
  const RecoveryException(this.code, this.message,
      {this.status = 0, this.retryAfter, this.attemptsLeft});

  @override
  String toString() => message;
}

/// Матни хато барои корбар аз рӯи рамзи сервер.
RecoveryException recoveryError(RecoveryResponse r) {
  final code = (r.body['code'] ?? '').toString();
  final server = (r.body['message'] ?? '').toString();
  final left = (r.body['attemptsLeft'] as num?)?.toInt();
  final retry = (r.body['retryAfter'] as num?)?.toInt();
  String msg;
  switch (code) {
    case 'invalid_code':
      msg = left != null && left > 0
          ? tr('recover.err.attemptsLeft', {'n': left})
          : tr('recover.err.wrongCode');
      break;
    case 'expired':
      msg = tr('recover.err.expired');
      break;
    case 'locked':
      msg = tr('recover.err.locked');
      break;
    case 'need_username':
      msg = tr('recover.needUsername');
      break;
    case 'invalid_token':
      msg = tr('recover.err.tokenInvalid');
      break;
    default:
      msg = server.isNotEmpty ? server : tr('recover.err.generic');
  }
  return RecoveryException(code.isEmpty ? 'http_${r.status}' : code, msg,
      status: r.status, retryAfter: retry, attemptsLeft: left);
}

class RecoveryRepository {
  RecoveryRepository({RecoveryTransport? transport})
      : _post = transport ?? _apiTransport;

  final RecoveryTransport _post;

  Future<RecoveryResponse> _call(String path, Map<String, dynamic> body,
      {bool long = false}) async {
    try {
      return await _post(path, body, long: long);
    } on SocketException {
      throw RecoveryException('network', tr('recover.err.network'));
    } on TimeoutException {
      throw RecoveryException('network', tr('recover.err.network'));
    } on HttpException {
      throw RecoveryException('network', tr('recover.err.network'));
    }
  }

  Future<RecoveryLookup> lookup(String identifier) async {
    final r = await _call(RecoveryEndpoints.lookup,
        {'identifier': identifier.trim()});
    if (r.status != 200) throw recoveryError(r);
    return RecoveryLookup.fromJson(r.body);
  }

  Future<RecoverySent> send(String identifier, String channel) async {
    final r = await _call(RecoveryEndpoints.send,
        {'identifier': identifier.trim(), 'channel': channel},
        long: true);
    if (r.status != 200) throw recoveryError(r);
    final b = r.body;
    return RecoverySent(
      channel: (b['channel'] ?? channel).toString(),
      to: (b['to'] ?? '').toString(),
      resendIn: (b['resendIn'] as num?)?.toInt() ?? 60,
      expiresIn: (b['expiresIn'] as num?)?.toInt() ?? 600,
      devOtp: b['otp']?.toString(),
    );
  }

  /// Token-и якдафъаина барои [reset].
  Future<String> verify(String identifier, String code) async {
    final r = await _call(RecoveryEndpoints.verify,
        {'identifier': identifier.trim(), 'code': code.trim()},
        long: true);
    final token = (r.body['resetToken'] ?? '').toString();
    if (r.status != 200 || token.isEmpty) throw recoveryError(r);
    return token;
  }

  /// Рамзи нав. Ҷавоб — мисли `/auth/login` (accessToken, refreshToken, user).
  Future<Map<String, dynamic>> reset(String token, String newPassword) async {
    final r = await _call(RecoveryEndpoints.reset,
        {'token': token.trim(), 'newPassword': newPassword},
        long: true);
    if (r.status != 200 || (r.body['accessToken'] ?? '').toString().isEmpty) {
      throw recoveryError(r);
    }
    return r.body;
  }

  /// «Кӯмак лозим». Бармегардонад: оё дархост аллакай кушода буд.
  Future<bool> requestHelp({
    required String identifier,
    required String contactEmail,
    required String fullName,
    String message = '',
  }) async {
    final r = await _call(RecoveryEndpoints.request, {
      'identifier': identifier.trim(),
      'contactEmail': contactEmail.trim(),
      'fullName': fullName.trim(),
      'message': message.trim(),
    }, long: true);
    if (r.status != 200) throw recoveryError(r);
    return r.body['alreadyPending'] == true;
  }
}

// ── Санҷиши рамз ────────────────────────────────────────────────────

/// Талаботи рамз (ҳамон қоидаи сервер: ≥ 8 аломат) ва маслиҳатҳо.
class PasswordCheck {
  final bool longEnough;
  final bool lettersAndDigits;
  final bool hasSymbol;
  const PasswordCheck(this.longEnough, this.lettersAndDigits, this.hasSymbol);

  /// 0..3 — барои нишондиҳандаи қувват.
  int get score =>
      (longEnough ? 1 : 0) + (lettersAndDigits ? 1 : 0) + (hasSymbol ? 1 : 0);
}

PasswordCheck checkPassword(String pw) {
  final hasLetter = RegExp(r'[^\W\d_]', unicode: true).hasMatch(pw);
  final hasDigit = RegExp(r'\d').hasMatch(pw);
  final hasSymbol = RegExp(r'[^\w\s]', unicode: true).hasMatch(pw) ||
      pw.contains('_');
  return PasswordCheck(pw.runes.length >= 8, hasLetter && hasDigit, hasSymbol);
}

/// Хато барои рамзи нав ва такрори он; null — мувофиқ.
String? newPasswordError(String pw, String confirm) {
  if (pw.runes.length < 8) return tr('recover.tooShort');
  if (pw.trim().isEmpty) return tr('recover.tooShort');
  if (pw != confirm) return tr('recover.mismatch');
  return null;
}
