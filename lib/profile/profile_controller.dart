import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';

class ProfileController extends ChangeNotifier {
  final String userId;
  final ProfileRepository _repo = ProfileRepository();

  ProfileController({required this.userId});

  UserModel? profile;
  List<PostModel> posts = [];
  List<ReelModel> reels = [];

  bool isLoading = false;
  String? error;

  Future<void> loadProfile() async {
    isLoading = true;
    notifyListeners();

    try {
      profile = await _repo.getProfile(userId);
      posts = await _repo.getUserPosts(userId);
      reels = await _repo.getUserReels(userId);
      error = null;
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFollow() async {
    if (profile == null) return;

    final wasFollowing = profile!.isFollowing;
    profile = profile!.copyWith(isFollowing: !wasFollowing);
    notifyListeners();

    try {
      if (wasFollowing) {
        await _repo.unfollow(userId);
      } else {
        await _repo.follow(userId);
      }
    } catch (_) {
      profile = profile!.copyWith(isFollowing: wasFollowing);
      notifyListeners();
    }
  }
}
