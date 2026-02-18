import 'dart:convert';

import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class FeedRepository {
  // ================= FEED =================

  Future<List<PostModel>> fetchFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.posts,
      query: {
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final List list = jsonDecode(response.body) as List;
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  // ================= POST ACTIONS =================

  Future<void> likePost(String postId) async {
    await ApiClient.post('/posts/$postId/like');
  }

  Future<void> savePost(String postId) async {
    await ApiClient.post('/posts/$postId/save');
  }

  Future<void> deletePost(String postId) async {
    await ApiClient.delete('/posts/$postId');
  }

  // ================= COMMENTS =================

  Future<List<CommentModel>> fetchComments(String postId) async {
    final response =
        await ApiClient.get('/posts/$postId/comments');

    final List list = jsonDecode(response.body) as List;
    return list.map((e) => CommentModel.fromJson(e)).toList();
  }

  Future<CommentModel> addComment({
    required String postId,
    required String text,
  }) async {
    final response = await ApiClient.post(
      '/posts/$postId/comments',
      body: {'text': text},
    );

    return CommentModel.fromJson(
      jsonDecode(response.body),
    );
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
  }) async {
    await ApiClient.post(
      '/posts/$postId/comments/$commentId/like',
    );
  }
}
