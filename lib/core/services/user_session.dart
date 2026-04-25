import 'package:flutter/foundation.dart';

class UserSession {
  UserSession._();

  static String? userId;
  static String? username;

  // ValueNotifier — Stories ва Bottom Tab автоматӣ update мешаванд
  static final ValueNotifier<String?> avatarNotifier =
      ValueNotifier<String?>(null);

  static String? get avatar => avatarNotifier.value;
  static set avatar(String? v) => avatarNotifier.value = v;
}
