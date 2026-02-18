class ApiEndpoints {
  // AUTH
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';

  // USERS / PROFILE
  static String userProfile(String userId) => '/users/$userId';
  static const String updateProfile = '/profile';

  static String followers(String userId) => '/users/$userId/followers';
  static String following(String userId) => '/users/$userId/following';

  static String toggleFollow(String userId) => '/follow/$userId';
  static String acceptFollow(String userId) => '/follow/$userId/accept';
  static String declineFollow(String userId) => '/follow/$userId/decline';

  // POSTS / FEED
  static const String posts = '/posts';
  static const String comments = '/comments';
  static const String likes = '/likes';

  // STORIES / REELS
  static const String stories = '/stories';
  static const String reels = '/reels';

  // CHAT
  static const String chat = '/chat';

  // NOTIFICATIONS
  static const String notifications = '/notifications';

  // SEARCH
  static const String search = '/search';

  // MEDIA
  static const String mediaUpload = '/media/upload';

  // ADMIN
  static const String admin = '/admin';
}
