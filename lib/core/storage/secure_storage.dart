import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  static Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  static Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  static Future<void> clear() {
    return _storage.deleteAll();
  }
}
