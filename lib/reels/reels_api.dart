import '../core/api.dart';
import '../models/reel_model.dart';
import 'dart:convert';

class ReelsApi {
  static Future<List<Reel>> getReels() async {
    final res = await Api.get('/reels');

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Reel.fromJson(e)).toList();
    } else {
      throw Exception('Error loading reels');
    }
  }
}
