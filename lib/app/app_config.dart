class AppConfig {
  AppConfig._(); // ⛔ no instance

  static String? _appName;
  static String? _baseUrl;
  static bool _enableLogs = false;
  static bool _initialized = false;

  // ================= GETTERS =================

  static String get appName {
    _assertInitialized();
    return _appName!;
  }

  static String get apiBaseUrl {
    _assertInitialized();
    return _baseUrl!;
  }

  // backward compatibility
  static String get baseUrl => apiBaseUrl;

  static bool get enableLogs {
    _assertInitialized();
    return _enableLogs;
  }

  static bool get isInitialized => _initialized;

  // ================= INIT =================

  static void initialize({
    required String appName,
    required String baseUrl,
    bool enableLogs = false,
  }) {
    _appName = appName;
    _baseUrl = _normalizeBaseUrl(baseUrl);
    _enableLogs = enableLogs;
    _initialized = true;
  }

  // ================= HELPERS =================

  static void _assertInitialized() {
    if (!_initialized) {
      throw Exception(
        '❌ AppConfig is not initialized. '
        'Call AppConfig.initialize() in main.dart before using it.',
      );
    }
  }

  static String _normalizeBaseUrl(String url) {
    // remove trailing slash
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }
}
