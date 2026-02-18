import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import 'api_interceptors.dart';

class ApiClient {
  ApiClient._();

  /// ✅ Singleton instance
  static final ApiClient instance = ApiClient._();

  static final http.Client _client = http.Client();

  String? _authToken;

  // ==================================================
  // AUTH TOKEN
  // ==================================================

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  // ==================================================
  // URI builder
  // ⚠️ AppConfig.apibaseUrl (на apiBaseUrl!)
  // ==================================================

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apibaseUrl}$path')
        .replace(queryParameters: query);
  }

  // ==================================================
  // INTERNAL REQUEST BUILDER
  // ==================================================

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path, query));

    request.headers['Content-Type'] = 'application/json';

    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }

    await ApiInterceptors.attachHeaders(request);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    return ApiInterceptors.handleResponse(response);
  }

  // ==================================================
  // INSTANCE METHODS (АСОСӢ – ИНҲОРО ИСТИФОДА КУН)
  // ==================================================

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
  }) {
    return _send('GET', path, query: query);
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send('POST', path, body: body);
  }

  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send('PUT', path, body: body);
  }

  Future<http.Response> delete(String path) {
    return _send('DELETE', path);
  }

  // ==================================================
  // STATIC API (BACKWARD COMPATIBILITY)
  // ==================================================

  static Future<http.Response> getStatic(
    String path, {
    Map<String, String>? query,
  }) {
    return instance.get(path, query: query);
  }

  static Future<http.Response> postStatic(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return instance.post(path, body: body);
  }

  static Future<http.Response> putStatic(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return instance.put(path, body: body);
  }

  static Future<http.Response> deleteStatic(String path) {
    return instance.delete(path);
  }
}
