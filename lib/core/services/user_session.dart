import 'package:flutter/foundation.dart';

class UserSession {
  UserSession._();

  static String? userId;
  static String? username;

  // ValueNotifier — UI-ро автоматӣ rebuild мекунад
  static final ValueNotifier<String?> avatarNotifier =
      ValueNotifier<String?>(null);

  static String? get avatar => avatarNotifier.value;
  static set avatar(String? v) => avatarNotifier.value = v;
}
