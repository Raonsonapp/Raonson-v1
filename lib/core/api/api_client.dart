import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../app/app_config.dart';
import '../storage/token_storage.dart';

/// Хатои ҷавоби сервер (4xx/5xx).
///
/// ⚠️ Чаро ин синф лозим шуд.
///
/// `post`/`put`/`delete` ҳангоми 400, 401, 403, 429 ё 500 хато
/// НАМЕПАРТОЯНД — онҳо `Response`-ро бармегардонанд. Пас коди зерин,
/// ки дар барнома даҳҳо ҷо такрор мешуд, ҲЕҶ ГОҲ кор намекард:
///
/// ```dart
/// _set(userId, true);            // фавран «Обуна шуд» менависем
/// try {
///   await ApiClient.instance.post('/follow/$userId');
/// } catch (_) {
///   _set(userId, false);         // ← ин сатр ҳеҷ гоҳ иҷро намешуд
/// }
/// ```
///
/// Натиҷа: сервер рад мекард, вале дар экран «Обуна шуд» мемонд.
/// Корбар баъди навсозӣ мебинад, ки обуна нашудааст — «функсия кор
/// намекунад».
///
/// Барои ҳамин усулҳои `…Ok` ҳастанд: онҳо ҳамон коранд, вале
/// хатои серверро мепартоянд. Дар ҷои даъват танҳо ном иваз мешавад
/// — `post` → `postOk` — ва `catch`-и аллакай навишташуда зинда
/// мешавад.
class ApiException implements Exception {
  final int status;
  final String body;
  const ApiException(this.status, this.body);

  /// Матни `{"message": "..."}`-и сервер, агар бошад.
  String? get message {
    try {
      final m = jsonDecode(body);
      final s = (m is Map ? m['message'] : null)?.toString();
      return (s == null || s.isEmpty) ? null : s;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ApiException($status): ${message ?? body}';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Ҷавобро месанҷад ва ҳангоми хато `ApiException` мепартояд.
  static http.Response _ok(http.Response r) {
    if (r.statusCode >= 400) throw ApiException(r.statusCode, r.body);
    return r;
  }

  Future<http.Response> getOk(String path, {Map<String, String>? query}) async =>
      _ok(await get(path, query: query));

  Future<http.Response> postOk(String path, {Map<String, dynamic>? body}) async =>
      _ok(await post(path, body: body));

  Future<http.Response> putOk(String path, {Map<String, dynamic>? body}) async =>
      _ok(await put(path, body: body));

  Future<http.Response> patchOk(String path, {Map<String, dynamic>? body}) async =>
      _ok(await patch(path, body: body));

  Future<http.Response> deleteOk(String path) async => _ok(await delete(path));

  static final http.Client _client = http.Client();

  String? _authToken;
  void setAuthToken(String? token) => _authToken = token;
  String? get authToken => _authToken;

  String? _refreshToken;
  void setRefreshToken(String? t) => _refreshToken = t;

  Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null) h['Authorization'] = 'Bearer $_authToken';
    return h;
  }

  Uri _uri(String path, [Map<String, String>? q]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: q);

  // ✅ Timeout кӯтоҳ — корбар зиёд мунтазир намемонад
  static const _timeout     = Duration(seconds: 8);
  static const _longTimeout = Duration(seconds: 30);

  // ✅ Smart GET: 2 кӯшиш, timeout кӯтоҳ
  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    return _withRetry(() =>
        _client.get(_uri(path, query), headers: _headers()).timeout(_timeout));
  }

  // ── External API (iTunes, etc.) — без Authorization header ──
  Future<http.Response> rawGet(String fullUrl) async {
    return _client.get(Uri.parse(fullUrl)).timeout(_timeout);
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    return _withRetry(() =>
        _client.post(_uri(path), headers: _headers(),
            body: body != null ? jsonEncode(body) : null).timeout(_timeout));
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    return _withRetry(() =>
        _client.put(_uri(path), headers: _headers(),
            body: body != null ? jsonEncode(body) : null).timeout(_timeout));
  }

  Future<http.Response> patch(String path, {Map<String, dynamic>? body}) async {
    return _withRetry(() =>
        _client.patch(_uri(path), headers: _headers(),
            body: body != null ? jsonEncode(body) : null).timeout(_timeout));
  }

  Future<http.Response> delete(String path) async {
    return _withRetry(() =>
        _client.delete(_uri(path), headers: _headers()).timeout(_timeout));
  }

  Future<http.Response> upload(String path, {Map<String, dynamic>? body}) =>
      _client.post(_uri(path), headers: _headers(),
          body: body != null ? jsonEncode(body) : null).timeout(_longTimeout);

  // ✅ Retry: 2 кӯшиш бо 1 сония фосила
  Future<http.Response> _withRetry(
      Future<http.Response> Function() request) async {
    for (int i = 0; i < 2; i++) {
      try {
        final response = await request();
        // 401 → як бор token-ро нав мекунем ва дархостро такрор мекунем.
        if (response.statusCode == 401 && i == 0 && _refreshToken != null) {
          final refreshed = await _tryRefresh();
          if (refreshed) continue; // retry бо token-и нав (headers нав мешаванд)
        }
        return response;
      } on SocketException {
        if (i == 1) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      } on TimeoutException {
        if (i == 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        rethrow;
      }
    }
    throw const SocketException('No internet');
  }

  Completer<bool>? _refreshCompleter;

  /// Токени дастрасиро нав мекунад — барои он ки берун аз дархости
  /// оддӣ низ истифода шавад.
  ///
  /// ⚠️ Ба сокет лозим аст. Сокет токенро дар суроға мебарад ва
  /// худаш 401-ро идора карда наметавонад: ҳамон токени кӯҳнаро
  /// абадан такрор мекард.
  ///
  /// Агар токени навсозӣ набошад, `false` бармегардад — бе кӯшиши
  /// бефоида.
  Future<bool> refreshSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    return _tryRefresh();
  }

  Future<bool> _tryRefresh() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    _refreshCompleter = Completer<bool>();
    try {
      final res = await _client.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newToken = data['accessToken']?.toString();
        final newRefresh = data['refreshToken']?.toString();
        if (newToken != null && newToken.isNotEmpty) {
          _authToken = newToken;
          await TokenStorage.saveAccessToken(newToken);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            _refreshToken = newRefresh;
            await TokenStorage.saveRefreshToken(newRefresh);
          }
          _refreshCompleter!.complete(true);
          return true;
        }
      }
      _refreshCompleter!.complete(false);
    } catch (_) {
      _refreshCompleter!.complete(false);
    } finally {
      _refreshCompleter = null;
    }
    return false;
  }

  // Aliases
  Future<http.Response> getRequest(String path, {Map<String, String>? query}) =>
      get(path, query: query);
  Future<http.Response> postRequest(String path, {Map<String, dynamic>? body}) =>
      post(path, body: body);
  Future<http.Response> putRequest(String path, {Map<String, dynamic>? body}) =>
      put(path, body: body);
  Future<http.Response> deleteRequest(String path) => delete(path);
}
