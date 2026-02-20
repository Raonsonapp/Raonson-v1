import 'dart:io';
import 'package:flutter/foundation.dart';

import '../upload/upload_manager.dart';

class CreatePostController extends ChangeNotifier {
  final UploadManager _uploadManager = UploadManager();

  final ValueNotifier<List<File>> media = ValueNotifier<List<File>>([]);
  bool isUploading = false;

  void addMedia(File file) {
    media.value = [...media.value, file];
  }

  void removeMedia(File file) {
    media.value = media.value.where((f) => f != file).toList();
  }

  Future<void> publishPost({
    required String caption,
  }) async {
    if (media.value.isEmpty || isUploading) return;

    isUploading = true;
    notifyListeners();

    try {
      await _uploadManager.uploadPost(
        caption: caption,
        media: media.value,
      );

      media.value = [];
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    media.dispose();
    super.dispose();
  }
}
