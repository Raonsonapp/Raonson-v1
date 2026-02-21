import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app/app_config.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  static final http.Client _client = http.Client();

  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null) h['Authorization'] = 'Bearer $_authToken';
    return h;
  }

  Uri _uri(String path, [Map<String, String>? q]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: q);

  // 70 seconds - enough for Render free plan cold start (50s)
  static const _t = Duration(seconds: 70);

  Future<http.Response> get(String p, {Map<String, String>? query}) =>
      _client.get(_uri(p, query), headers: _headers()).timeout(_t);

  Future<http.Response> post(String p, {Map<String, dynamic>? body}) =>
      _client
          .post(_uri(p), headers: _headers(),
              body: body != null ? jsonEncode(body) : null)
          .timeout(_t);

  Future<http.Response> put(String p, {Map<String, dynamic>? body}) =>
      _client
          .put(_uri(p), headers: _headers(),
              body: body != null ? jsonEncode(body) : null)
          .timeout(_t);

  Future<http.Response> delete(String p) =>
      _client.delete(_uri(p), headers: _headers()).timeout(_t);

  Future<http.Response> getRequest(String p, {Map<String, String>? query}) =>
      get(p, query: query);
  Future<http.Response> postRequest(String p, {Map<String, dynamic>? body}) =>
      post(p, body: body);
  Future<http.Response> putRequest(String p, {Map<String, dynamic>? body}) =>
      put(p, body: body);
  Future<http.Response> deleteRequest(String p) => delete(p);
}
