class ApiEndpoints {
  static const String base = '';

  // AUTH
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';

  // USERS
  static const String users = '/users';
  static const String profile = '/profile';

  // FEED / POSTS
  static const String posts = '/posts';
  static const String comments = '/comments';
  static const String likes = '/likes';

  // SOCIAL
  static const String follow = '/follow';
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
