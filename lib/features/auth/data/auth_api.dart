import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api.dart';

class AuthApi {
  static Future<bool> registerStep1(String phone) async {
    final url = Uri.parse(
      "${ApiConstants.baseUrl}/auth/register/step1",
    );

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "phone": phone,
      }),
    );

    return response.statusCode == 200;
  }
}
