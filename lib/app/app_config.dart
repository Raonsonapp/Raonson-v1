import 'package:flutter/widgets.dart';

class AppConfig {
  static late String appName;
  static late String baseUrl;
  static late bool enableLogs;

  static Future<void> initialize({
    required String appName,
    required String baseUrl,
    bool enableLogs = false,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    AppConfig.appName = appName;
    AppConfig.baseUrl = baseUrl;
    AppConfig.enableLogs = enableLogs;
  }
}
