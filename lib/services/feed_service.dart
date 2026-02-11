import 'dart:convert';
import '../core/api/api.dart';
import '../models/post_model.dart';

class FeedService {
  static Future<List<PostModel>> getFeed() async {
    final res = await getRequest("/posts");

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => PostModel.fromJson(e)).toList();
    }
    return [];
  }
}
