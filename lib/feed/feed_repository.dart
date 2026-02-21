import 'dart:convert';

import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class FeedRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<PostModel>> fetchFeed({int limit = 20, int page = 1}) async {
    final response = await _api.getRequest(
      ApiEndpoints.posts,
      query: {'limit': '$limit', 'page': '$page'},
    );

    if (response.statusCode == 401) {
      throw Exception('Unauthorized – please log in again');
    }
    if (response.statusCode >= 400) {
      throw Exception('Server error ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final List list = body is Map ? (body['posts'] ?? []) : body as List;
    return list.map((e) => PostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> likePost(String postId) async {
    await _api.postRequest('/posts/$postId/like');
  }

  Future<void> savePost(String postId) async {
    await _api.postRequest('/posts/$postId/save');
  }

  Future<void> deletePost(String postId) async {
    await _api.deleteRequest('/posts/$postId');
  }

  Future<List<CommentModel>> fetchComments(String postId) async {
    final response = await _api.getRequest('/posts/$postId/comments');
    if (response.statusCode >= 400) throw Exception('Failed to load comments');
    final body = jsonDecode(response.body);
    final List list = body is Map ? (body['comments'] ?? []) : body as List;
    return list.map((e) => CommentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CommentModel> addComment({
    required String postId,
    required String text,
  }) async {
    final response = await _api.postRequest(
      '/posts/$postId/comments',
      body: {'text': text},
    );
    if (response.statusCode >= 400) throw Exception('Failed to add comment');
    return CommentModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
  }) async {
    await _api.postRequest('/posts/$postId/comments/$commentId/like');
  }
}
