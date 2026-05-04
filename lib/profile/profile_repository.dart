// lib/profile/profile_repository.dart
import 'dart:convert';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import 'highlight_model.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  Future<UserModel> getProfile(String userId) async {
    final path = userId == 'me' ? '/profile/me'
        : _isUUID(userId) ? '/users/$userId' : '/profile/$userId';
    final res = await _api.get(path);
    if (res.statusCode >= 400) throw Exception('Корбар ёфт нашуд');
    final body = jsonDecode(res.body);
    final j = (body is Map && body.containsKey('user')) ? body['user'] : body;
    return UserModel.fromJson(j as Map<String, dynamic>);
  }

  Future<bool> isUsernameTaken(String username, String currentUsername) async {
    if (username.toLowerCase() == currentUsername.toLowerCase()) return false;
    try {
      return (await _api.get('/profile/$username')).statusCode == 200;
    } catch (_) { return false; }
  }

  Future<void> updateProfile({
    required String username, String? bio, String? fullName,
    String? website, bool? isPrivate, String? avatar,
  }) async {
    final res = await _api.put('/profile/', body: {
      'username': username,
      if (bio       != null) 'bio':       bio,
      if (fullName  != null) 'fullName':  fullName,
      if (website   != null) 'website':   website,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (avatar    != null && avatar.isNotEmpty) 'avatar': avatar,
    });
    if (res.statusCode == 409) throw Exception('409: Username already taken');
    if (res.statusCode >= 400) {
      final b = jsonDecode(res.body) as Map<String,dynamic>? ?? {};
      throw Exception(b['message'] ?? 'Update failed ${res.statusCode}');
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    if (userId == 'me') {
      final res = await _api.get('/profile/me');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('posts')) {
        return (body['posts'] as List)
            .map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
      }
      return [];
    }
    final res = await _api.get('/users/$userId/posts');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['posts'] ?? []) as List;
    return list.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  Future<List<PostModel>> getTaggedPosts(String userId) async {
    try {
      final res = await _api.get('/users/$userId/tagged');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['posts'] ?? []) as List;
      return list.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<ReelModel>> getUserReels(String userId) async {
    try {
      final res = await _api.get('/users/$userId/reels');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['reels'] ?? []) as List;
      return list.map((e) => ReelModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<List<HighlightModel>> getHighlights(String userId) async {
    try {
      final res = await _api.get('/highlights/$userId');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['highlights'] ?? []) as List;
      return list.map((e) => HighlightModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> follow(String uid)   async => _api.post(ApiEndpoints.follow(uid));
  Future<void> unfollow(String uid) async => _api.post(ApiEndpoints.unfollow(uid));

  Future<void> blockUser(String uid) async =>
      _api.post('/users/$uid/block');
  Future<void> unblockUser(String uid) async =>
      _api.post('/users/$uid/unblock');

  Future<void> pinPost(String postId, bool pin) async =>
      _api.post('/posts/$postId/pin', body: {'pin': pin});
  Future<void> deletePost(String postId) async =>
      _api.delete('/posts/$postId');

  Future<List<UserModel>> getFollowers(String uid) async {
    final res = await _api.get('/users/$uid/followers');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['followers'] ?? []) as List;
    return list.map((e) => UserModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  Future<List<UserModel>> getFollowing(String uid) async {
    final res = await _api.get('/users/$uid/following');
    if (res.statusCode >= 400) return [];
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['following'] ?? []) as List;
    return list.map((e) => UserModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  bool _isUUID(String s) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
             r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);
}
