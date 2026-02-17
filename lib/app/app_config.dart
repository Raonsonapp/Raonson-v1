// lib/app/app_config.dart
import 'package:flutter/foundation.dart';

/// Global application configuration.
/// This file is FINAL and must not be modified once locked.
@immutable
class AppConfig {
  // ===== App Identity =====
  static const String appName = 'Raonson';
  static const String appBundleId = 'com.raonson.app';

  // ===== Environment =====
  /// Set to true only for production builds.
  static const bool isProduction = bool.fromEnvironment(
    'RAONSON_PROD',
    defaultValue: false,
  );

  /// Enable verbose logs in non-production.
  static bool get enableLogs => !isProduction;

  // ===== Network =====
  /// Backend base URL (Render – LIVE)
  static const String baseUrl = 'https://raonson-v1.onrender.com';

  /// API prefix (keep empty if backend mounts on root)
  static const String apiPrefix = '';

  /// HTTP timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // ===== Pagination =====
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // ===== Media =====
  static const int maxUploadSizeMB = 50;
  static const List<String> allowedImageMime = <String>[
    'image/jpeg',
    'image/png',
    'image/webp',
  ];
  static const List<String> allowedVideoMime = <String>[
    'video/mp4',
    'video/quicktime',
    'video/webm',
  ];

  // ===== Security =====
  /// JWT header key expected by backend
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  // ===== Realtime / Sockets =====
  /// If sockets share the same origin, keep null to derive from baseUrl
  static const String? socketUrl = null;

  // ===== Feature Flags =====
  static const bool enableStories = true;
  static const bool enableReels = true;
  static const bool enableChat = true;
  static const bool enableNotifications = true;

  // ===== Utilities =====
  /// Build full API URL for an endpoint.
  static String api(String path) {
    if (path.startsWith('/')) {
      return '$baseUrl$apiPrefix$path';
    }
    return '$baseUrl$apiPrefix/$path';
  }

  const AppConfig._(); // no instances
}
