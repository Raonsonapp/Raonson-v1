import 'package:flutter/widgets.dart';

class AppConfig {
  static late String appName;
  static late String apiBaseUrl;
  static late bool enableLogs;

  static Future<void> initialize({
    bool enableLogs = false,
    required String appName,
    required String baseUrl,
    bool logs = true,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    AppConfig.appName = appName;
    apiBaseUrl = baseUrl;
    enableLogs = logs;
  }
}
