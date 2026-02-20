class ApiEndpoints {
  // AUTH
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // USERS / PROFILE
  static String userProfile(String userId) => '/users/$userId';
  static const String updateProfile = '/profile';

  static String followers(String userId) => '/users/$userId/followers';
  static String following(String userId) => '/users/$userId/following';

  static String follow(String userId) => '/follow/$userId';
  static String unfollow(String userId) => '/unfollow/$userId';

  // POSTS / FEED
  static const String posts = '/posts';

  // CHAT
  static const String chat = '/chat';

  // NOTIFICATIONS
  static const String notifications = '/notifications';

  // STORIES / REELS
  static const String stories = '/stories';
  static const String reels = '/reels';
}
