import 'dart:io';
import 'package:flutter/foundation.dart';
import '../upload/upload_manager.dart';

class CreatePostController extends ChangeNotifier {
  final UploadManager _uploadManager = UploadManager();

  final ValueNotifier<List<File>> media = ValueNotifier<List<File>>([]);
  bool isUploading = false;

  Future<void> publishPost({
    required String caption,
    void Function(double)? onProgress,
  }) async {
    if (media.value.isEmpty || isUploading) return;

    isUploading = true;
    notifyListeners();

    try {
      await _uploadManager.uploadPost(
        caption:    caption,
        media:      media.value,
        onProgress: onProgress,
      );
      media.value = [];
    } catch (e) {
      isUploading = false;
      notifyListeners();
      rethrow; // ← screen-да нишон медиҳад
    }

    isUploading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    media.dispose();
    super.dispose();
  }
}
