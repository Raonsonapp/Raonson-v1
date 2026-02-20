import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pick() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return null;
    return File(file.path);
  }
}
