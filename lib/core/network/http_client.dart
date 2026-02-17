import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import '../api/api_interceptors.dart';

class HttpClient {
  static final http.Client _client = http.Client();

  static Uri _buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path')
        .replace(queryParameters: query);
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final request = http.Request('GET', _buildUri(path, query));
    await ApiInterceptors.attachHeaders(request);

    final response =
        await http.Response.fromStream(await _client.send(request));
    final handled = ApiInterceptors.handleResponse(response);

    return jsonDecode(handled.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request('POST', _buildUri(path));
    await ApiInterceptors.attachHeaders(request);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response =
        await http.Response.fromStream(await _client.send(request));
    final handled = ApiInterceptors.handleResponse(response);

    return jsonDecode(handled.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request('PUT', _buildUri(path));
    await ApiInterceptors.attachHeaders(request);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final response =
        await http.Response.fromStream(await _client.send(request));
    final handled = ApiInterceptors.handleResponse(response);

    return jsonDecode(handled.body) as Map<String, dynamic>;
  }

  static Future<void> delete(String path) async {
    final request = http.Request('DELETE', _buildUri(path));
    await ApiInterceptors.attachHeaders(request);

    final response =
        await http.Response.fromStream(await _client.send(request));
    ApiInterceptors.handleResponse(response);
  }
}
