import 'package:flutter/widgets.dart';

class AppConfig {
  static late String appName;
  static late String apibaseUrl;
  static late bool enableLogs;

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
