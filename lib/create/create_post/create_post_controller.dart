import 'dart:io';
import 'package:flutter/foundation.dart';

import '../upload/upload_manager.dart';

class CreatePostController extends ChangeNotifier {
  final UploadManager _uploadManager = UploadManager();

  final ValueNotifier<List<File>> media = ValueNotifier([]);
  bool isUploading = false;

  void addMedia(File file) {
    media.value = [...media.value, file];
  }

  Future<void> publishPost({required String caption}) async {
    if (media.value.isEmpty || isUploading) return;

    isUploading = true;
    notifyListeners();

    try {
      await _uploadManager.uploadPost(
        caption: caption,
        files: media.value,
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
