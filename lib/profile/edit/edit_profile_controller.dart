import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../profile_repository.dart';

class EditProfileController extends ChangeNotifier {
  final ProfileRepository _repo = ProfileRepository();

  final usernameController = TextEditingController();
  final bioController = TextEditingController();

  bool isPrivate = false;
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  late UserModel _original;

  Future<void> loadCurrentProfile() async {
    isLoading = true;
    notifyListeners();

    try {
      _original = await _repo.getMyProfile();
      usernameController.text = _original.username;
      bioController.text = _original.bio ?? '';
      isPrivate = _original.isPrivate;
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

  Future<bool> save() async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await _repo.updateProfile(
        username: usernameController.text.trim(),
        bio: bioController.text.trim(),
        isPrivate: isPrivate,
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
