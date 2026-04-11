import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:app/infrastructure/network/auth_interceptor.dart';
import 'package:app/infrastructure/config/oauth_config.dart';

class MockTokenDio extends Mock implements Dio {}
class MockRequestInterceptorHandler extends Mock implements RequestInterceptorHandler {}
class MockErrorInterceptorHandler extends Mock implements ErrorInterceptorHandler {}
class MockResponse<T> extends Mock implements Response<T> {}
class MockRequestOptions extends Mock implements RequestOptions {}

void main() {
  late MockTokenDio mockTokenDio;
  late AuthInterceptor authInterceptor;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(DioException(requestOptions: RequestOptions(path: '')));
  });

  setUp(() {
    mockTokenDio = MockTokenDio();
    authInterceptor = AuthInterceptor(tokenDio: mockTokenDio);
  });

  group('AuthInterceptor', () {
    test('onRequest adds authorization header successfully', () async {
      final mockHandler = MockRequestInterceptorHandler();
      final options = RequestOptions(path: '/test');

      final tokenResponse = MockResponse<Map<String, dynamic>>();
      when(() => tokenResponse.data).thenReturn({
        'access_token': 'my-mocked-token',
        'expires_in': 3600,
      });

      when(() => mockTokenDio.post(OAuthConfig.tokenUrl, data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => tokenResponse);

      await Future(() => authInterceptor.onRequest(options, mockHandler));

      expect(options.headers['Authorization'], 'Bearer my-mocked-token');
      verify(() => mockHandler.next(options)).called(1);
    });

    test('onRequest uses cached token if valid', () async {
      final mockHandler1 = MockRequestInterceptorHandler();
      final options1 = RequestOptions(path: '/test1');

      final tokenResponse = MockResponse<Map<String, dynamic>>();
      when(() => tokenResponse.data).thenReturn({
        'access_token': 'my-cached-token',
        'expires_in': 3600,
      });

      when(() => mockTokenDio.post(any(), data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => tokenResponse);

      // First Request
      await Future(() => authInterceptor.onRequest(options1, mockHandler1));

      final mockHandler2 = MockRequestInterceptorHandler();
      final options2 = RequestOptions(path: '/test2');

      // Second Request should not query Dio again
      await Future(() => authInterceptor.onRequest(options2, mockHandler2));

      expect(options2.headers['Authorization'], 'Bearer my-cached-token');
      verify(() => mockHandler2.next(options2)).called(1);
      
      // Token endpoint should only be called once
      verify(() => mockTokenDio.post(any(), data: any(named: 'data'), options: any(named: 'options'))).called(1);
    });

    test('onRequest throws if token request fails', () async {
      final mockHandler = MockRequestInterceptorHandler();
      final options = RequestOptions(path: '/test');

      when(() => mockTokenDio.post(any(), data: any(named: 'data'), options: any(named: 'options')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      await Future(() => authInterceptor.onRequest(options, mockHandler));

      verify(() => mockHandler.reject(any())).called(1);
      verifyNever(() => mockHandler.next(any()));
    });

    test('onError on 401 retries original request with new token', () async {
      final mockHandler = MockErrorInterceptorHandler();
      final originOptions = RequestOptions(path: '/original', headers: {});
      final dioError = DioException(
        requestOptions: originOptions,
        response: Response(requestOptions: originOptions, statusCode: 401),
      );

      final tokenResponse = MockResponse<Map<String, dynamic>>();
      when(() => tokenResponse.data).thenReturn({
        'access_token': 'new-retry-token',
        'expires_in': 3600,
      });

      final retryResponse = MockResponse();
      
      when(() => mockTokenDio.post(any(), data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => tokenResponse);

      when(() => mockTokenDio.fetch(any())).thenAnswer((_) async => retryResponse);

      // To make the condition err.response?.statusCode == 401 && _accessToken != null work:
      // First populate the token.
      await Future(() => authInterceptor.onRequest(RequestOptions(path: ''), MockRequestInterceptorHandler()));

      await Future(() => authInterceptor.onError(dioError, mockHandler));

      verify(() => mockHandler.resolve(retryResponse)).called(1);
      
      final captured = verify(() => mockTokenDio.fetch(captureAny())).captured;
      final retryOptions = captured.first as RequestOptions;
      expect(retryOptions.headers['Authorization'], 'Bearer new-retry-token');
    });

    test('onError passes through if not a 401', () async {
      final mockHandler = MockErrorInterceptorHandler();
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/original'),
        response: Response(requestOptions: RequestOptions(path: '/original'), statusCode: 500),
      );

      await Future(() => authInterceptor.onError(dioError, mockHandler));

      verify(() => mockHandler.next(dioError)).called(1);
      verifyNever(() => mockTokenDio.fetch(any()));
    });
  });
}
