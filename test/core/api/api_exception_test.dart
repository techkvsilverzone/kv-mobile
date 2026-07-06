import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';

RequestOptions _opts() => RequestOptions(path: '/test');

void main() {
  test('connection errors map to NetworkException', () {
    final e = DioException(requestOptions: _opts(), type: DioExceptionType.connectionError);
    expect(mapDioException(e), isA<NetworkException>());
  });

  test('timeouts map to NetworkException', () {
    final e = DioException(requestOptions: _opts(), type: DioExceptionType.receiveTimeout);
    expect(mapDioException(e), isA<NetworkException>());
  });

  test('401 responses map to AuthException with the server message', () {
    final e = DioException(
      requestOptions: _opts(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: _opts(),
        statusCode: 401,
        data: {'message': 'Not authorized'},
      ),
    );
    final mapped = mapDioException(e);
    expect(mapped, isA<AuthException>());
    expect(mapped.message, 'Not authorized');
  });

  test('400 responses map to ValidationException with field errors', () {
    final e = DioException(
      requestOptions: _opts(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: _opts(),
        statusCode: 400,
        data: {
          'message': 'Validation failed',
          'errors': {'email': 'Invalid email'},
        },
      ),
    );
    final mapped = mapDioException(e) as ValidationException;
    expect(mapped.message, 'Validation failed');
    expect(mapped.fieldErrors, {'email': 'Invalid email'});
  });

  test('500 responses map to ServerException with the status code', () {
    final e = DioException(
      requestOptions: _opts(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: _opts(),
        statusCode: 500,
        data: {'message': 'Boom'},
      ),
    );
    final mapped = mapDioException(e) as ServerException;
    expect(mapped.statusCode, 500);
    expect(mapped.message, 'Boom');
  });

  test('missing message falls back to a generic string', () {
    final e = DioException(
      requestOptions: _opts(),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: _opts(), statusCode: 500, data: {}),
    );
    expect(mapDioException(e).message, 'Something went wrong.');
  });
}
