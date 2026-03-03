/// In-memory session - set after login:
/// UserSession.userId = data['user']['_id'];
class UserSession {
  UserSession._();
  static String? userId;
  static String? username;
  static String? avatar;
}
