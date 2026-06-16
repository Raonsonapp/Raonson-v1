// lib/profile/profile_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../core/services/follow_service.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';
import '../create/upload/upload_manager.dart';
import 'highlight_model.dart';

class ProfileController extends ChangeNotifier {
  final String userId;
  final bool   byUsername;
  final ProfileRepository _repo = ProfileRepository(ApiClient.instance);

  ProfileController({required this.userId, this.byUsername = false});

  bool get isOwnProfile =>
      userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == userId) ||
      (profile != null && profile!.id == UserSession.userId);

  UserModel?           profile;
  List<PostModel>      posts        = [];
  List<PostModel>      taggedPosts  = [];
  List<PostModel>      savedPosts   = [];
  List<ReelModel>      reels        = [];
  List<HighlightModel> highlights   = [];
  bool                 isLoading    = false;
  String?              error;

  // Pinned posts first
  List<PostModel> get sortedPosts {
    final pinned   = posts.where((p) => p.isPinned).toList();
    final unpinned = posts.where((p) => !p.isPinned).toList();
    return [...pinned, ...unpinned];
  }

  Future<void> loadProfile() async {
    isLoading = true;
    notifyListeners();
    try {
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

  Future<void> loadSavedPosts() async {
    try {
      savedPosts = await _repo.getSavedPosts();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> uploadAvatar(File file) async {
    try {
      final url = await UploadManager().uploadAvatar(file);
      if (url.isNotEmpty && profile != null) {
        profile = profile!.copyWith(avatar: url);
        UserSession.avatar = url;
        // Persist via API
        await _repo.updateProfile(
          username: profile!.username,
          avatar:   url,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> removeAvatar() async {
    try {
      await _repo.removeAvatar();
      if (profile != null) {
        profile = profile!.copyWith(avatar: '');
        UserSession.avatar = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleFollow() async {
    if (profile == null || isOwnProfile) return;
    final u = profile!;
    if (u.isPrivate && !u.isFollowing) {
      profile = u.copyWith(followRequestSent: true);
      notifyListeners();
      try { await _repo.follow(u.id); }
      catch (_) { profile = u; notifyListeners(); }
      return;
    }
    final was   = u.isFollowing;
    final delta = was ? -1 : 1;
    profile = u.copyWith(
        isFollowing:    !was,
        followersCount: (u.followersCount + delta).clamp(0, 999999999));
    FollowService.instance.prime(u.id, !was); // синхрон бо reels/search/home
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
    profile = u.copyWith(
        isBlocked:   !blocked,
        isFollowing: blocked ? u.isFollowing : false);
    notifyListeners();
    try {
      blocked ? await _repo.unblockUser(u.id) : await _repo.blockUser(u.id);
    } catch (_) {
      profile = u;
      notifyListeners();
    }
  }

  Future<void> togglePinPost(PostModel post) async {
    final idx = posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;
    posts[idx] = posts[idx].copyWith(isPinned: !posts[idx].isPinned);
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

  /// UI-only: пост аллакай дар сервер нест шуд (аз экрани кушодашуда).
  /// Танҳо рӯйхатҳоро навсозӣ мекунем — realtime, бе дубора API.
  void removePostById(String id) {
    posts.removeWhere((p) => p.id == id);
    savedPosts.removeWhere((p) => p.id == id);
    taggedPosts.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // Highlights CRUD
  Future<void> createHighlight(String title, String coverUrl,
      List<String> storyIds, {List<HighlightItem> items = const []}) async {
    try {
      final h = await _repo.createHighlight(
          title: title, coverUrl: coverUrl, storyIds: storyIds, items: items);
      highlights.add(h);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> renameHighlight(String id, String title) async {
    final idx = highlights.indexWhere((h) => h.id == id);
    if (idx >= 0) {
      highlights[idx] = highlights[idx].copyWith(title: title);
      notifyListeners();
    }
    await _repo.updateHighlight(id, title: title);
  }

  Future<void> updateHighlightItems(String id, List<HighlightItem> items) async {
    final idx = highlights.indexWhere((h) => h.id == id);
    if (idx >= 0) {
      highlights[idx] = highlights[idx].copyWith(
          items: items,
          coverUrl: items.isNotEmpty ? items.first.url : '');
      notifyListeners();
    }
    await _repo.updateHighlight(id,
        items: items, coverUrl: items.isNotEmpty ? items.first.url : '');
  }

  Future<void> deleteHighlight(String id) async {
    highlights.removeWhere((h) => h.id == id);
    notifyListeners();
    try { await _repo.deleteHighlight(id); }
    catch (_) {
      highlights = await _repo.getHighlights(profile?.id ?? userId);
      notifyListeners();
    }
  }
}
