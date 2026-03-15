import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/services/user_session.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';

class ProfileController extends ChangeNotifier {
  final String userId;
  final ProfileRepository _repo = ProfileRepository(ApiClient.instance);

  ProfileController({required this.userId});

  // Own profile if userId = 'me' OR matches session userId
  bool get isOwnProfile =>
      userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == userId) ||
      (profile != null && profile!.id == UserSession.userId);

  UserModel?      profile;
  List<PostModel> posts   = [];
  List<ReelModel> reels   = [];
  bool            isLoading = false;
  String?         error;

  Future<void> loadProfile() async {
    isLoading = true;
    notifyListeners();
    try {
      profile = await _repo.getProfile(userId);
      posts   = await _repo.getUserPosts(
          profile?.id ?? userId);
      reels   = await _repo.getUserReels(
          profile?.id ?? userId);
      error   = null;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFollow() async {
    if (profile == null || isOwnProfile) return;
    final was   = profile!.isFollowing;
    final delta = was ? -1 : 1;

    // Optimistic update — UI дарҳол иваз мешавад
    profile = profile!.copyWith(
      isFollowing:    !was,
      followersCount: (profile!.followersCount + delta).clamp(0, 999999999),
    );
    notifyListeners();

    try {
      if (was) {
        await _repo.unfollow(profile!.id);
      } else {
        await _repo.follow(profile!.id);
      }
    } catch (_) {
      // Rollback
      profile = profile!.copyWith(
        isFollowing:    was,
        followersCount: (profile!.followersCount - delta).clamp(0, 999999999),
      );
      notifyListeners();
    }
  }
}
