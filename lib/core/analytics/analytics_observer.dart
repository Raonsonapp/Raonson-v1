import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// Logs a `screen_view` event whenever a named route is pushed or popped
/// back to. Attach to `MaterialApp(navigatorObservers: [...])`.
class AnalyticsObserver extends NavigatorObserver {
  void _log(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    AnalyticsService.instance.logScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _log(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _log(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _log(newRoute);
  }
}
