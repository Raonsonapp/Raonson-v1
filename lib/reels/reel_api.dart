import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';

class ReelApi {
  static Future<List<dynamic>> getReels() async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/reels'),
    );
    return jsonDecode(res.body);
  }

  static Future<void> toggleLike(String id) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/reels/like/$id'),
    );
  }

  static Future<void> toggleSave(String id) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/reels/save/$id'),
    );
  }

  static Future<void> addView(String id) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/reels/view/$id'),
    );
  }
}
