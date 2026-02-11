import 'dart:io';
import '../core/api/upload_api.dart';

class UploadService {
  static Future<bool> uploadImage(File file) {
    return UploadApi.uploadFile(file: file, type: "image");
  }

  static Future<bool> uploadVideo(File file) {
    return UploadApi.uploadFile(file: file, type: "video");
  }
}
