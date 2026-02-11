import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'reel_model.dart';

class ReelApi {
  static Future<List<Reel>> getReels() async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/reels'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Reel.fromJson(e)).toList();
  }

  static Future<void> toggleLike(String id) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/reels/like/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static Future<void> toggleSave(String id) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/reels/save/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static Future<void> addView(String id) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/reels/view/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
