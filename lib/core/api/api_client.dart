import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../app/app_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

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
