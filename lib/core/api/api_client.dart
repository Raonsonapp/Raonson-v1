import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  static final http.Client _client = http.Client();

  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  static const _timeout = Duration(seconds: 20);

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _client
        .get(_uri(path, query), headers: _headers())
        .timeout(_timeout);
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) {
    return _client
        .post(_uri(path), headers: _headers(),
            body: body != null ? jsonEncode(body) : null)
        .timeout(_timeout);
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) {
    return _client
        .put(_uri(path), headers: _headers(),
            body: body != null ? jsonEncode(body) : null)
        .timeout(_timeout);
  }

  Future<http.Response> delete(String path) {
    return _client
        .delete(_uri(path), headers: _headers())
        .timeout(_timeout);
  }

  // Backward compatibility
  Future<http.Response> getRequest(String path,
          {Map<String, String>? query}) =>
      get(path, query: query);
  Future<http.Response> postRequest(String path,
          {Map<String, dynamic>? body}) =>
      post(path, body: body);
  Future<http.Response> putRequest(String path,
          {Map<String, dynamic>? body}) =>
      put(path, body: body);
  Future<http.Response> deleteRequest(String path) => delete(path);
}
