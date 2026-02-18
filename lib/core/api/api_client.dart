import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  static final http.Client _client = http.Client();

  String? _authToken;

  // ================= AUTH HEADER =================
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
    return Uri.parse('${AppConfig.apibaseUrl}$path')
        .replace(queryParameters: query);
  }

  // ================= HTTP METHODS =================

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
  }) {
    return _client.get(
      _uri(path, query),
      headers: _headers(),
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _client.post(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _client.put(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String path) {
    return _client.delete(
      _uri(path),
      headers: _headers(),
    );
  }
}
