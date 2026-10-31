import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_session.dart';
import '../config/env.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';

Dio buildDio({
  required SecureTokenStorage tokenStorage,
  required Future<void> Function() onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await onUnauthorized();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return response.data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<dynamic> post(String path, {Object? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<dynamic> put(String path, {Object? data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<dynamic> delete(String path, {Object? data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  return buildDio(
    tokenStorage: tokenStorage,
    onUnauthorized: () => ref.read(authSessionProvider.notifier).clearSession(),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
