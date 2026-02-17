import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import 'api_interceptors.dart';

class ApiClient {
  ApiClient._();

  /// Singleton instance
  static final ApiClient instance = ApiClient._();

  static final http.Client _client = http.Client();

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  // ================= STATIC METHODS =================

  static Future<http.Response> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final request = http.Request('GET', _uri(path, query));
    await ApiInterceptors.attachHeaders(request);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    return ApiInterceptors.handleResponse(response);
  }

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request('POST', _uri(path));
    await ApiInterceptors.attachHeaders(request);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    return ApiInterceptors.handleResponse(response);
  }

  static Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request('PUT', _uri(path));
    await ApiInterceptors.attachHeaders(request);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    return ApiInterceptors.handleResponse(response);
  }

  static Future<http.Response> delete(String path) async {
    final request = http.Request('DELETE', _uri(path));
    await ApiInterceptors.attachHeaders(request);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    return ApiInterceptors.handleResponse(response);
  }

  // ================= INSTANCE WRAPPERS =================
  // ✅ барои ApiClient.instance.post(...)

  Future<http.Response> getRequest(
    String path, {
    Map<String, String>? query,
  }) {
    return ApiClient.get(path, query: query);
  }

  Future<http.Response> postRequest(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return ApiClient.post(path, body: body);
  }

  Future<http.Response> putRequest(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return ApiClient.put(path, body: body);
  }

  Future<http.Response> deleteRequest(String path) {
    return ApiClient.delete(path);
  }

  /// ⭐ МАХЗ ИН МЕТОД барои login_controller.dart
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return ApiClient.post(path, body: body);
  }
}
