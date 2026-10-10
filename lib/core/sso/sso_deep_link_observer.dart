// lib/core/sso/sso_deep_link_observer.dart
//
// `raonson://sso?code=…` вақте барнома АЛЛАКАЙ кушода аст.
//
// Flutter линки воридшударо ба Navigator ҳамчун `pushNamed(path)`
// мерасонад ва схема ва host-ро мепартояд: `raonson://sso?code=X` ба
// `/?code=X` табдил меёфт — экрани вуруд ҳеҷ гоҳ намекушод. Ин observer
// пеш аз WidgetsApp сабт мешавад (дар main(), пеш аз runApp), пас URI-и
// ПУРРА-ро аввал мебинад ва танҳо линки SSO-ро мегирад; ҳамаи линкҳои
// дигар ба роҳи пештара мераванд.
//
// Оғози сард (барнома бо ҳамин линк кушода шуд) дар onGenerateRoute
// (app_controller.dart) коркард мешавад.
import 'package:flutter/material.dart';

import '../../auth/sso/tajikshop_sign_in_screen.dart';
import 'tajikshop_sso.dart';

class SsoDeepLinkObserver with WidgetsBindingObserver {
  SsoDeepLinkObserver(this.navigatorKey);
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final code = TajikshopSso.codeFromUri(routeInformation.uri);
    if (code == null) return false;
    final nav = navigatorKey.currentState;
    if (nav == null) return false;
    nav.push(MaterialPageRoute(
        builder: (_) => TajikshopSignInScreen(code: code)));
    return true;
  }
}
