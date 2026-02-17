import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

class ApiInterceptors {
  static Future<http.BaseRequest> attachHeaders(
    http.BaseRequest request,
  ) async {
    final token = await TokenStorage.getAccessToken();

    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    return request;
  }

  static http.Response handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }

    if (response.statusCode == 403) {
      throw Exception('Forbidden');
    }

    if (response.statusCode >= 500) {
      throw Exception('Server error');
    }

    throw Exception(
      'Request failed: ${response.statusCode} ${response.body}',
    );
  }
}
