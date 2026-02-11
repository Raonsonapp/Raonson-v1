import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MediaPicker {
  static Future<File?> pickImage() async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery);
    return file != null ? File(file.path) : null;
  }

  static Future<File?> pickVideo() async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickVideo(source: ImageSource.gallery);
    return file != null ? File(file.path) : null;
  }
}
