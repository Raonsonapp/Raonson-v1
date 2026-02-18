class ApiEndpoints {
  // ==================================================
  // AUTH
  // ==================================================
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String verifyOtp = '/auth/verify-otp';

  // ==================================================
  // USERS / PROFILE
  // ==================================================
  static String userProfile(String userId) => '/users/$userId';
  static const String updateProfile = '/profile';

  static String followers(String userId) => '/users/$userId/followers';
  static String following(String userId) => '/users/$userId/following';

  static String toggleFollow(String userId) => '/follow/$userId';
  static String acceptFollow(String userId) => '/follow/$userId/accept';
  static String declineFollow(String userId) => '/follow/$userId/decline';

  // ==================================================
  // POSTS / FEED
  // ==================================================
  static const String posts = '/posts';

  static String likePost(String postId) => '/posts/$postId/like';
  static String savePost(String postId) => '/posts/$postId/save';
  static String deletePost(String postId) => '/posts/$postId';

  // ==================================================
  // COMMENTS
  // ==================================================
  static String comments(String postId) => '/posts/$postId/comments';

  static String addComment(String postId) => '/posts/$postId/comments';
  static String likeComment({
    required String postId,
    required String commentId,
  }) =>
      '/posts/$postId/comments/$commentId/like';

  // ==================================================
  // STORIES / REELS
  // ==================================================
  static const String stories = '/stories';
  static const String reels = '/reels';

  // ==================================================
  // CHAT
  // ==================================================
  static const String chatList = '/chat';
  static String chatMessages(String userId) => '/chat/$userId';
  static const String sendMessage = '/chat/send';

  static String markChatRead(String chatId) => '/chat/$chatId/read';
  static String deleteChat(String chatId) => '/chat/$chatId';

  // ==================================================
  // NOTIFICATIONS
  // ==================================================
  static const String notifications = '/notifications';

  // ==================================================
  // SEARCH
  // ==================================================
  static const String search = '/search';

  // ==================================================
  // MEDIA
  // ==================================================
  static const String mediaUpload = '/media/upload';

  // ==================================================
  // ADMIN
  // ==================================================
  static const String admin = '/admin';
}
