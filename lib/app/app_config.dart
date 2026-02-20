import 'package:flutter/widgets.dart';

class AppConfig {
  static late String appName;
  static late String apibaseUrl;
  static late bool enableLogs;

  // ---------- COMPAT ----------
  static String get apiBaseUrl => apibaseUrl;
  static String get baseUrl => apibaseUrl;

  static Future<void> initialize({
    required String appName,
    required String baseUrl,
    bool enableLogs = false,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    AppConfig.appName = appName;
    AppConfig.apibaseUrl = baseUrl;
    AppConfig.enableLogs = enableLogs;
  }
}
