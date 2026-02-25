import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image OR video from gallery (shows all media)
  static Future<File?> pick() async {
    try {
      // pickMedia shows both images and videos
      final XFile? file = await _picker.pickMedia(
        mediaOptions: const MediaOptions(
          allowMultiple: false,
          imageOptions: ImageOptions(imageQuality: 85),
        ),
      );
      if (file == null) return null;
      return File(file.path);
    } catch (_) {
      // Fallback to image only if pickMedia not supported
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return null;
      return File(file.path);
    }
  }

  static Future<File?> pickImageOnly() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    return File(file.path);
  }

  static Future<File?> pickVideoOnly() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (file == null) return null;
    return File(file.path);
  }

  static bool isVideo(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  static bool isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }
}
