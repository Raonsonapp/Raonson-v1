import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'story_model.dart';

class StoryApi {
  static Future<List<Story>> getStories() async {
    final token = await TokenStorage.read();

    final res = await http.get(
      Uri.parse('${Api.baseUrl}/stories'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as List;
    return data.map((e) => Story.fromJson(e)).toList();
  }
}
