import 'dart:async';
import 'error_mapper.dart';

class ErrorHandler {
  static AppError handle(dynamic error) {
    if (error is AppError) {
      return error;
    }

    if (error is TimeoutException) {
      return ErrorMapper.timeout();
    }

    if (error is FormatException) {
      return const AppError(
        type: AppErrorType.validation,
        message: 'Invalid response format',
      );
    }

    if (error is Map) {
      final status = error['statusCode'];
      final message = error['message'];
      if (status is int) {
        return ErrorMapper.fromHttp(
          statusCode: status,
          message: message is String ? message : null,
        );
      }
    }

    return ErrorMapper.unknown(
      error.toString(),
    );
  }
}
