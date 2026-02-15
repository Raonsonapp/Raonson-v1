import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PickedMedia {
  final File file;
  final bool isVideo;

  PickedMedia({required this.file, required this.isVideo});
}

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<List<PickedMedia>> pickMultiple() async {
    final List<XFile> files = await _picker.pickMultipleMedia();

    return files.map((f) {
      final isVideo = f.path.endsWith('.mp4') || f.path.endsWith('.mov');
      return PickedMedia(file: File(f.path), isVideo: isVideo);
    }).toList();
  }
}
