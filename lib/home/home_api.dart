import '../core/api.dart';

class HomeApi {
  static Future<List<dynamic>> fetchFeed() async {
    final res = await Api.get('/posts/feed');
    return res;
  }

  static Future<int> toggleLike(String postId) async {
    final res = await Api.post('/posts/$postId/like');
    return res['likes'];
  }

  static Future<bool> toggleSave(String postId) async {
    final res = await Api.post('/posts/$postId/save');
    return res['saved'];
  }

  static Future<List<dynamic>> getComments(String postId) async {
    return await Api.get('/posts/$postId/comments');
  }

  static Future<void> addComment(String postId, String text) async {
    await Api.post('/posts/$postId/comments', body: {'text': text});
  }
}
