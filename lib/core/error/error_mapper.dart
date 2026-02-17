enum AppErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  unknown,
}

class AppError {
  final AppErrorType type;
  final String message;
  final int? statusCode;

  const AppError({
    required this.type,
    required this.message,
    this.statusCode,
  });
}

class ErrorMapper {
  static AppError fromHttp({
    required int statusCode,
    String? message,
  }) {
    switch (statusCode) {
      case 400:
        return AppError(
          type: AppErrorType.validation,
          message: message ?? 'Invalid request',
          statusCode: statusCode,
        );
      case 401:
        return AppError(
          type: AppErrorType.unauthorized,
          message: 'Authentication required',
          statusCode: statusCode,
        );
      case 403:
        return AppError(
          type: AppErrorType.forbidden,
          message: 'Access denied',
          statusCode: statusCode,
        );
      case 404:
        return AppError(
          type: AppErrorType.notFound,
          message: 'Resource not found',
          statusCode: statusCode,
        );
      case 408:
        return AppError(
          type: AppErrorType.timeout,
          message: 'Request timeout',
          statusCode: statusCode,
        );
      case 500:
      default:
        return AppError(
          type: AppErrorType.server,
          message: 'Server error',
          statusCode: statusCode,
        );
    }
  }

  static AppError network() {
    return const AppError(
      type: AppErrorType.network,
      message: 'No internet connection',
    );
  }

  static AppError timeout() {
    return const AppError(
      type: AppErrorType.timeout,
      message: 'Connection timed out',
    );
  }

  static AppError unknown([String? message]) {
    return AppError(
      type: AppErrorType.unknown,
      message: message ?? 'Unexpected error occurred',
    );
  }
}
