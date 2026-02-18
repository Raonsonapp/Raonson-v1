import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import 'api_interceptors.dart';

class ApiClient {
  ApiClient._();

  /// Singleton instance
  static final ApiClient instance = ApiClient._();

  static final http.Client _client = http.Client();

  // ================= URI =================
  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  // ================= INTERNAL =================
  Future<http.Response> _send(http.Request request) async {
    await ApiInterceptors.attachHeaders(request);
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return ApiInterceptors.handleResponse(response);
  }

  // ================= PUBLIC INSTANCE API =================

  Future<http.Response> getRequest(
    String path, {
    Map<String, String>? query,
  }) {
    final request = http.Request('GET', _uri(path, query));
    return _send(request);
  }

  Future<http.Response> postRequest(
    String path, {
    Map<String, dynamic>? body,
  }) {
    final request = http.Request('POST', _uri(path));
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _send(request);
  }

  Future<http.Response> putRequest(
    String path, {
    Map<String, dynamic>? body,
  }) {
    final request = http.Request('PUT', _uri(path));
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _send(request);
  }

  Future<http.Response> deleteRequest(String path) {
    final request = http.Request('DELETE', _uri(path));
    return _send(request);
  }
}
