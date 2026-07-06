import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException(super.message);
}

class AuthException extends ApiException {
  const AuthException(super.message);
}

class ValidationException extends ApiException {
  const ValidationException(super.message, this.fieldErrors);
  final Map<String, String> fieldErrors;
}

class ServerException extends ApiException {
  const ServerException(this.statusCode, super.message);
  final int statusCode;
}

const _networkErrorTypes = {
  DioExceptionType.connectionError,
  DioExceptionType.connectionTimeout,
  DioExceptionType.receiveTimeout,
  DioExceptionType.sendTimeout,
};

ApiException mapDioException(DioException e) {
  if (_networkErrorTypes.contains(e.type) || e.response == null) {
    return const NetworkException('Unable to reach the server. Check your connection.');
  }

  final response = e.response!;
  final statusCode = response.statusCode ?? 0;
  final message = _extractMessage(response.data) ?? 'Something went wrong.';

  if (statusCode == 401) {
    return AuthException(message);
  }
  if (statusCode == 400 || statusCode == 422) {
    return ValidationException(message, _extractFieldErrors(response.data));
  }
  return ServerException(statusCode, message);
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String) return message;
    final error = data['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
  }
  return null;
}

Map<String, String> _extractFieldErrors(dynamic data) {
  if (data is Map<String, dynamic> && data['errors'] is Map) {
    final raw = data['errors'] as Map;
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
  return const {};
}
