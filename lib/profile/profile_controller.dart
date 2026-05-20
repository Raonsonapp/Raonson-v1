// lib/profile/profile_controller.dart
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';
import 'highlight_model.dart';

class ProfileController extends ChangeNotifier {
  final String userId;
  final bool byUsername;
  final ProfileRepository _repo = ProfileRepository(ApiClient.instance);

  ProfileController({required this.userId, this.byUsername = false});

  bool get isOwnProfile =>
      userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == userId) ||
      (profile != null && profile!.id == UserSession.userId);

  UserModel?           profile;
  List<PostModel>      posts      = [];
  List<PostModel>      taggedPosts = [];
  List<ReelModel>      reels      = [];
  List<HighlightModel> highlights = [];
  bool                 isLoading  = false;
  String?              error;

  // Sorted posts — pinned first
  List<PostModel> get sortedPosts {
    final pinned   = posts.where((p) => p.isPinned).toList();
    final unpinned = posts.where((p) => !p.isPinned).toList();
    return [...pinned, ...unpinned];
  }

  Future<void> loadProfile() async {
    isLoading = true;
    notifyListeners();
    try {
      // If byUsername, resolve username to userId first
      final resolvedId = byUsername
          ? await _repo.getUserIdByUsername(userId)
          : userId;
      profile    = await _repo.getProfile(resolvedId);
      posts      = await _repo.getUserPosts(profile?.id ?? userId);
      reels      = await _repo.getUserReels(profile?.id ?? userId);
      highlights = await _repo.getHighlights(profile?.id ?? userId);
      error      = null;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadTaggedPosts() async {
    try {
      taggedPosts = await _repo.getTaggedPosts(profile?.id ?? userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleFollow() async {
    if (profile == null || isOwnProfile) return;
    final u = profile!;

    // Private account → send request
    if (u.isPrivate && !u.isFollowing) {
      profile = u.copyWith(followRequestSent: true);
      notifyListeners();
      try { await _repo.follow(u.id); }
      catch (_) { profile = u; notifyListeners(); }
      return;
    }

    // Normal follow/unfollow
    final was   = u.isFollowing;
    final delta = was ? -1 : 1;
    profile = u.copyWith(
        isFollowing: !was,
        followersCount: (u.followersCount + delta).clamp(0, 999999999));
    notifyListeners();
    try {
      was ? await _repo.unfollow(u.id) : await _repo.follow(u.id);
    } catch (_) {
      profile = u;
      notifyListeners();
    }
  }

  Future<void> toggleBlock() async {
    if (profile == null || isOwnProfile) return;
    final u       = profile!;
    final blocked = u.isBlocked;
    profile = u.copyWith(isBlocked: !blocked, isFollowing: blocked ? u.isFollowing : false);
    notifyListeners();
    try {
      blocked
          ? await _repo.unblockUser(u.id)
          : await _repo.blockUser(u.id);
    } catch (_) {
      profile = u;
      notifyListeners();
    }
  }

  Future<void> togglePinPost(PostModel post) async {
    final idx = posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;
    final updated = posts[idx].copyWith(isPinned: !posts[idx].isPinned);
    posts[idx] = updated;
    notifyListeners();
    try {
      await _repo.pinPost(post.id, !post.isPinned);
    } catch (_) {
      posts[idx] = post;
      notifyListeners();
    }
  }

  Future<void> deletePost(PostModel post) async {
    posts.removeWhere((p) => p.id == post.id);
    notifyListeners();
    try { await _repo.deletePost(post.id); }
    catch (_) { posts.add(post); notifyListeners(); }
  }
}
