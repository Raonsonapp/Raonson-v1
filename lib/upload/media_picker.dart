import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PickedMedia {
  final File file;
  final bool isVideo;

  PickedMedia(this.file, this.isVideo);
}

class MediaPicker {
  static final _picker = ImagePicker();

  static Future<List<PickedMedia>> pickMultiple() async {
    final files = await _picker.pickMultipleMedia();
    return files.map((f) {
      final isVideo = f.path.endsWith('.mp4') || f.path.endsWith('.mov');
      return PickedMedia(File(f.path), isVideo);
    }).toList();
  }
}
