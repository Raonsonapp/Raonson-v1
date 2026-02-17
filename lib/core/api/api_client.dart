import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import 'api_interceptors.dart';

class ApiClient {
  static final http.Client _client = http.Client();

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path')
        .replace(queryParameters: query);
  }

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
}
