import 'package:flutter/material.dart';

import 'app_state.dart';
import 'app_routes.dart';
import '../navigation/bottom_nav/bottom_nav_scaffold.dart';
import '../reels/reels_feed/reels_screen.dart';
import '../chat/inbox/chat_list_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../create/create_post/create_post_screen.dart';
import '../create/create_story/create_story_screen.dart';
import '../notifications/notifications_screen.dart';
import '../stories/story_viewer.dart';
import '../models/story_model.dart';

// AUTH SCREENS
import '../auth/login/login_screen.dart';
import '../auth/register/register_screen.dart';

class AppController {
  final AppState appState;

  AppController(this.appState);

  String get initialRoute {
    if (!appState.isInitialized) return AppRoutes.splash;
    return appState.isAuthenticated ? AppRoutes.home : AppRoutes.login;
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // AUTH
      case AppRoutes.login:
        return _page(const LoginScreen());

      case AppRoutes.register:
        return _page(const RegisterScreen());

      // MAIN TABS
      case AppRoutes.home:
        return _page(const BottomNavScaffold());

      case AppRoutes.reels:
        return _page(const ReelsScreen());

      case AppRoutes.chat:
        return _page(const ChatListScreen());

      case AppRoutes.search:
        return _page(const SearchScreen());

      case AppRoutes.profile:
        return _page(const ProfileScreen(userId: 'me'));

      // ACTIONS
      case AppRoutes.create:
        return _page(const CreatePostScreen());

      case AppRoutes.notifications:
        return _page(const NotificationsScreen());

      case '/create-story':
        return _page(const CreateStoryScreen());

      case '/edit-profile':
        return _page(const ProfileScreen(userId: 'me'));

      // STORY VIEWER - tap on story circle
      case '/story-viewer':
        final story = settings.arguments as StoryModel?;
        if (story == null) return _page(const BottomNavScaffold());
        return _page(StoryViewer(
          story: story,
          onComplete: () {},
        ));

      // Default - go home if logged in, else login
      default:
        return _page(
          appState.isAuthenticated
              ? const BottomNavScaffold()
              : const LoginScreen(),
        );
    }
  }

  MaterialPageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}
