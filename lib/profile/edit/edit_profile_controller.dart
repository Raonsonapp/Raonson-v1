// lib/profile/edit/edit_profile_controller.dart
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../models/user_model.dart';
import '../profile_repository.dart';

class EditProfileController extends ChangeNotifier {
  final ProfileRepository _repo = ProfileRepository(ApiClient.instance);

  final nameController     = TextEditingController();
  final usernameController = TextEditingController();
  final bioController      = TextEditingController();
  final websiteController  = TextEditingController();
  final locationController = TextEditingController();

  String?   gender;
  DateTime? birthday;
  bool      isPrivate = false;
  bool      isLoading = false;
  bool      isSaving  = false;
  String?   error;

  late UserModel _original;
  String? get currentAvatarUrl =>
      _original.avatar.isNotEmpty ? _original.avatar : null;

  Future<void> loadCurrentProfile(String userId) async {
    isLoading = true;
    notifyListeners();
    try {
      _original = await _repo.getProfile(userId);
      nameController.text     = _original.fullName ?? '';
      usernameController.text = _original.username;
      bioController.text      = _original.bio      ?? '';
      websiteController.text  = _original.website  ?? '';
      isPrivate               = _original.isPrivate;
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

  Future<bool> save({
    String?  avatarUrl,
    bool     removeAvatar = false,
  }) async {
    isSaving = true;
    notifyListeners();
    try {
      await _repo.updateProfile(
        username:  usernameController.text.trim(),
        fullName:  nameController.text.trim(),
        bio:       bioController.text.trim(),
        website:   websiteController.text.trim(),
        isPrivate: isPrivate,
        gender:    gender,
        location:  locationController.text.trim(),
        birthday:  birthday?.toIso8601String().substring(0, 10),
        avatar:    removeAvatar ? '' : avatarUrl,
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
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    websiteController.dispose();
    locationController.dispose();
    super.dispose();
  }
}
