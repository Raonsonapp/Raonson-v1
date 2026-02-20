class AnalyticsEvents {
  // ================= APP =================
  static const appOpen = 'app_open';
  static const appBackground = 'app_background';

  // ================= AUTH =================
  static const login = 'login';
  static const register = 'register';
  static const logout = 'logout';

  // ================= FEED =================
  static const feedView = 'feed_view';
  static const postView = 'post_view';
  static const postLike = 'post_like';
  static const postComment = 'post_comment';
  static const postShare = 'post_share';
  static const postSave = 'post_save';

  // ================= CREATE =================
  static const createPost = 'create_post';
  static const createStory = 'create_story';
  static const uploadMedia = 'upload_media';

  // ================= STORIES =================
  static const storyView = 'story_view';
  static const storyLike = 'story_like';

  // ================= REELS =================
  static const reelView = 'reel_view';
  static const reelLike = 'reel_like';
  static const reelShare = 'reel_share';
  static const reelSave = 'reel_save';

  // ================= PROFILE =================
  static const profileView = 'profile_view';
  static const followUser = 'follow_user';
  static const unfollowUser = 'unfollow_user';
  static const editProfile = 'edit_profile';

  // ================= CHAT =================
  static const chatOpen = 'chat_open';
  static const messageSend = 'message_send';

  // ================= NOTIFICATIONS =================
  static const notificationOpen = 'notification_open';

  // ================= SETTINGS =================
  static const changePrivacy = 'change_privacy';
  static const changeTheme = 'change_theme';
}
