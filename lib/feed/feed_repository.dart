import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class FeedRepository {
  final ApiClient _api;

  FeedRepository(this._api);

  // ================= FEED =================

  /// Get home feed (latest posts)
  Future<List<PostModel>> fetchFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.get(
      ApiEndpoints.posts,
      query: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final List data = response.data as List;
    return data.map((e) => PostModel.fromJson(e)).toList();
  }

  // ================= POST ACTIONS =================

  Future<void> likePost(String postId) async {
    await _api.post(
      ApiEndpoints.likePost(postId),
    );
  }

  Future<void> savePost(String postId) async {
    await _api.post(
      ApiEndpoints.savePost(postId),
    );
  }

  Future<void> deletePost(String postId) async {
    await _api.delete(
      ApiEndpoints.deletePost(postId),
    );
  }

  // ================= COMMENTS =================

  Future<List<CommentModel>> fetchComments(String postId) async {
    final response = await _api.get(
      ApiEndpoints.comments(postId),
    );

    final List data = response.data as List;
    return data.map((e) => CommentModel.fromJson(e)).toList();
  }

  Future<CommentModel> addComment({
    required String postId,
    required String text,
  }) async {
    final response = await _api.post(
      ApiEndpoints.addComment(postId),
      body: {
        'text': text,
      },
    );

    return CommentModel.fromJson(response.data);
  }

  Future<void> likeComment({
    required String postId,
    required String commentId,
  }) async {
    await _api.post(
      ApiEndpoints.likeComment(
        postId: postId,
        commentId: commentId,
      ),
    );
  }
}
