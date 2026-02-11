import 'dart:convert';
import 'package:http/http.dart' as http;

const String BASE_URL = "https://raonson-me.onrender.com/api";

Future<http.Response> getRequest(String path, {String? token}) {
  return http.get(
    Uri.parse("$BASE_URL$path"),
    headers: {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
  );
}

Future<http.Response> postRequest(
  String path,
  Map<String, dynamic> body, {
  String? token,
}) {
  return http.post(
    Uri.parse("$BASE_URL$path"),
    headers: {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
    body: jsonEncode(body),
  );
}
