import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/infrastructure/network/api_exception.dart';

DioException _dioError({int? status, dynamic data, DioExceptionType? type}) {
  final requestOptions = RequestOptions(path: '/recipes');
  return DioException(
    requestOptions: requestOptions,
    type: type ?? DioExceptionType.badResponse,
    response: status == null
        ? null
        : Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: status,
            data: data,
          ),
  );
}

void main() {
  group('ApiException.fromDio', () {
    test('parses the {error: {code, message}} envelope', () {
      final e = ApiException.fromDio(
        'Failed to save recipe',
        _dioError(status: 400, data: {
          'error': {'code': 'invalid_json', 'message': 'Invalid request body'}
        }),
      );

      expect(e.statusCode, 400);
      expect(e.code, 'invalid_json');
      expect(e.serverMessage, 'Invalid request body');
      expect(e.isClientError, isTrue);
      expect(e.isServerError, isFalse);
      expect(e.isNetworkError, isFalse);
      expect(
        e.message,
        'Failed to save recipe (400): Invalid request body [invalid_json]',
      );
    });

    test('handles a message without a code', () {
      final e = ApiException.fromDio(
        'Failed to load recipes',
        _dioError(status: 500, data: {
          'error': {'message': 'boom'}
        }),
      );

      expect(e.code, isNull);
      expect(e.isServerError, isTrue);
      expect(e.message, 'Failed to load recipes (500): boom');
    });

    test('falls back to a top-level message field', () {
      final e = ApiException.fromDio(
        'Failed to load recipes',
        _dioError(status: 502, data: {'message': 'bad gateway'}),
      );

      expect(e.serverMessage, 'bad gateway');
      expect(e.message, 'Failed to load recipes (502): bad gateway');
    });

    test('uses status only when the body has no usable message', () {
      final e = ApiException.fromDio(
        'Failed to delete recipe',
        _dioError(status: 404, data: {'unexpected': true}),
      );

      expect(e.isNotFound, isTrue);
      expect(e.serverMessage, isNull);
      expect(e.message, 'Failed to delete recipe (404)');
    });

    test('treats a missing response as a network error', () {
      final e = ApiException.fromDio(
        'Failed to load recipes',
        _dioError(type: DioExceptionType.connectionTimeout),
      );

      expect(e.statusCode, isNull);
      expect(e.isNetworkError, isTrue);
      expect(e.message, 'Failed to load recipes (connectionTimeout)');
    });
  });
}
