import 'package:flutter/widgets.dart';

class AppConfig {
  static late String apiBaseUrl;
  static late bool enableLogs;

  static Future<void> initialize({
    required String baseUrl,
    bool logs = true,
  }) async {
    apiBaseUrl = baseUrl;
    enableLogs = logs;
    WidgetsFlutterBinding.ensureInitialized();
  }
}
