import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../models/user_model.dart';
import '../profile_repository.dart';

class EditProfileController extends ChangeNotifier {
  final ProfileRepository _repo =
      ProfileRepository(ApiClient.instance);

  final usernameController = TextEditingController();
  final bioController = TextEditingController();

  bool isPrivate = false;
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  String coverUrl = '';                       // баннери профил (Pro)
  List<Map<String, String>> links = [];       // линкҳои био (Pro)

  late UserModel _original;

  String? get currentAvatarUrl => _original.avatar.isNotEmpty ? _original.avatar : null;

  Future<void> loadCurrentProfile(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      _original = await _repo.getProfile(userId);
      usernameController.text = _original.username;
      bioController.text = _original.bio ?? '';
      isPrivate = _original.isPrivate;
      coverUrl = _original.coverUrl;
      links = _original.links.map((e) => Map<String, String>.from(e)).toList();
      error = null;
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  void togglePrivate(bool value) {
    isPrivate = value;
    notifyListeners();
  }

  Future<bool> save({dynamic bioSong, String? avatarUrl}) async {
    isSaving = true;
    notifyListeners();

    try {
      await _repo.updateProfile(
        username:  usernameController.text.trim(),
        bio:       bioController.text.trim(),
        isPrivate: isPrivate,
        avatar:    avatarUrl,
        bioSong:   (bioSong != null && bioSong.isEmpty != true)
            ? (bioSong.toJson() as Map<String, dynamic>)
            : null,
        coverUrl:  coverUrl,
        links:     links,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    bioController.dispose();
    super.dispose();
  }
}
