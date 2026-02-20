class Session {
  static String? token;

  static bool get isLoggedIn => token != null;

  static void setToken(String t) {
    token = t;
  }

  static void clear() {
    token = null;
  }
}
