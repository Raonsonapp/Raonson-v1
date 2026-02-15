import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseUploadService {
  static final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// 📤 Upload image OR video → returns download URL
  static Future<String> uploadFile(File file, {required bool isVideo}) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final id = _uuid.v4();

    final ref = _storage.ref().child(
      isVideo ? 'videos/$id.$ext' : 'images/$id.$ext',
    );

    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }
}
