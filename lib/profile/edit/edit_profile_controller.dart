import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../profile_repository.dart';

class EditProfileController extends ChangeNotifier {
  final ProfileRepository _repo = ProfileRepository();

  final usernameController = TextEditingController();

  bool isPrivate = false;
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  late UserModel _original;

  Future<void> loadCurrentProfile(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      _original = await _repo.getProfile(userId);
      usernameController.text = _original.username;
      isPrivate = _original.isPrivate;
      error = null;
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> save() async {
    isSaving = true;
    notifyListeners();

    try {
      await _repo.updateProfile(
        username: usernameController.text.trim(),
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
    super.dispose();
  }
}
