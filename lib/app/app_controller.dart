import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../create/create_reel/create_reel_screen.dart';
import 'app_state.dart';
import 'app_routes.dart';
import '../navigation/bottom_nav/bottom_nav_scaffold.dart';
import '../reels/reels_feed/reels_screen.dart';
import '../chat/inbox/chat_list_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';
import '../create/create_post/create_post_screen.dart';
import '../stories/story_viewer.dart';
import '../stories/story_controller.dart';
import '../models/story_model.dart';
import '../create/create_story/create_story_screen.dart';
import '../notifications/notifications_screen.dart';
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
      case AppRoutes.login:
        return _page(const LoginScreen());
      case AppRoutes.register:
        return _page(const RegisterScreen());
      case AppRoutes.home:
        return _page(const BottomNavScaffold());
      case '/create-reel':
        return _page(const CreateReelScreen());
      case AppRoutes.reels:
        return _page(const ReelsScreen());
      case AppRoutes.chat:
        return _page(const ChatListScreen());
      case AppRoutes.search:
        return _page(const SearchScreen());
      case AppRoutes.profile:
        return _page(const ProfileScreen(userId: 'me'));

      // Профили дигар корбар
      case '/user-profile':
      case '/profile':
        final uid = settings.arguments;
        final userId = (uid is String && uid.isNotEmpty) ? uid : 'me';
        return _page(ProfileScreen(userId: userId));

      case AppRoutes.create:
        return _page(const CreatePostScreen());
      case AppRoutes.notifications:
        return _page(const NotificationsScreen());

      // Story viewer — onComplete → markViewed
      case '/story-viewer':
        final story = settings.arguments as StoryModel;
        return MaterialPageRoute(
          builder: (ctx) => StoryViewer(
            story: story,
            onComplete: () {
              // markViewed — story дида шуд → ҳалқа dark green
              try {
                final ctrl = ctx.read<StoryController>();
                ctrl.markViewed(story.id);
              } catch (_) {}
            },
          ),
        );

      case '/create-story':
        return _page(const CreateStoryScreen());
      default:
        return _page(const LoginScreen());
    }
  }

  MaterialPageRoute _page(Widget w) =>
      MaterialPageRoute(builder: (_) => w);
}
