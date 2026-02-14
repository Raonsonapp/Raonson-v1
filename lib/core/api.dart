import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class Api {
  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}$path'),
    );
    return jsonDecode(res.body);
  }

  static Future<dynamic> post(String path) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}$path'),
    );
    return jsonDecode(res.body);
  }
}
