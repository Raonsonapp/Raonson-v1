import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reel_model.dart';

class ReelsApi {
  static const baseUrl = 'https://raonson-v1.onrender.com';

  static Future<List<Reel>> fetchReels() async {
    final res = await http.get(Uri.parse('$baseUrl/reels'));
    final List data = jsonDecode(res.body);
    return data.map((e) => Reel.fromJson(e)).toList();
  }

  static Future<void> view(String id) async {
    await http.post(Uri.parse('$baseUrl/reels/$id/view'));
  }

  static Future<int> like(String id) async {
    final res = await http.post(Uri.parse('$baseUrl/reels/$id/like'));
    final data = jsonDecode(res.body);
    return data['likes'];
  }
}
