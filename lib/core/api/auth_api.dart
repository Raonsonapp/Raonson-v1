import 'dart:convert';
import 'api.dart';

class AuthApi {
  static Future<String?> login(String phone, String email) async {
    final res = await postRequest("/auth/login", {
      "phone": phone,
      "email": email,
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["token"];
    }
    return null;
  }
}
