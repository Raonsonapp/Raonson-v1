import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  /// Pick a single image or video from gallery
  static Future<File?> pick() async {
    final XFile? file = await _picker.pickMedia();
    if (file == null) return null;
    return File(file.path);
  }

  /// Pick only image
  static Future<File?> pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    return File(file.path);
  }

  /// Pick only video
  static Future<File?> pickVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (file == null) return null;
    return File(file.path);
  }

  /// Pick multiple images/videos
  static Future<List<File>> pickMultiple() async {
    final List<XFile> files = await _picker.pickMultipleMedia();
    return files.map((f) => File(f.path)).toList();
  }

  static bool isVideo(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }
}
