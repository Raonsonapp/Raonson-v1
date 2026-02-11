import 'dart:io';
import '../core/api/post_api.dart';

class PostService {
  static Future<bool> createImagePost(
      File file, String caption) {
    return PostApi.createPost(
      file: file,
      caption: caption,
      type: "image",
    );
  }

  static Future<bool> createVideoPost(
      File file, String caption) {
    return PostApi.createPost(
      file: file,
      caption: caption,
      type: "video",
    );
  }
}
