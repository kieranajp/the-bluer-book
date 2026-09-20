import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/infrastructure/auth/auth_repository.dart';
import 'package:app/infrastructure/auth/token_store.dart';
import 'package:app/infrastructure/network/auth_interceptor.dart';

/// Records every request it sees and replies from a queue of canned
/// responses (default: a 200 echoing the auth header back as the body).
class _StubAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<int Function(RequestOptions)> statusQueue = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final status = statusQueue.isNotEmpty
        ? statusQueue.removeAt(0)(options)
        : 200;
    // Encoded as a JSON string so Dio's default transformer (which always
    // decodes a json-content-type body) doesn't choke on it.
    return ResponseBody.fromString(
      jsonEncode(options.headers['Authorization']?.toString() ?? ''),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mirrors the real refresh()/signOut() persistence so the interceptor's
/// re-read of TokenStore actually observes the new session, without ever
/// touching AppAuth.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._store) : super(store: _store);

  final TokenStore _store;
  int refreshCalls = 0;

  /// Thrown instead of refreshing, when set.
  Object? failure;

  /// When set, `refresh` waits on this before answering — lets a test hold
  /// every caller inside one refresh at the same time.
  Completer<void>? gate;

  AuthSession Function(String refreshToken)? nextSession;

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    final session = (nextSession ?? _defaultSession)(refreshToken);
    await _store.write(session);
    return session;
  }

  AuthSession _defaultSession(String refreshToken) => AuthSession(
        accessToken: 'refreshed-access-token',
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

  @override
  Future<void> signOut() => _store.clear();
}

void main() {
  late TokenStore store;
  late _StubAdapter adapter;
  late _StubAdapter retryAdapter;
  late Dio retryClient;
  late _FakeAuthRepository fakeAuth;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = TokenStore();
    adapter = _StubAdapter();
    retryAdapter = _StubAdapter();
    retryClient = Dio()..httpClientAdapter = retryAdapter;
    fakeAuth = _FakeAuthRepository(store);
  });

  Dio buildDio({FutureOr<void> Function()? onSignedOut}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(
      store: store,
      auth: fakeAuth,
      onSignedOut: onSignedOut,
      retryClient: retryClient,
    ));
    return dio;
  }

  Future<void> seed({
    String accessToken = 'live-access-token',
    String? refreshToken = 'live-refresh-token',
    Duration? expiresIn = const Duration(hours: 1),
  }) async {
    await store.write(AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresIn == null ? null : DateTime.now().add(expiresIn),
    ));
  }

  test('a session that is not near expiry is attached, no refresh', () async {
    await seed();
    final dio = buildDio();

    final response = await dio.get('/recipes');

    expect(response.data, 'Bearer live-access-token');
    expect(fakeAuth.refreshCalls, 0);
  });

  test('a session expiring within 30s refreshes before the request goes out',
      () async {
    await seed(expiresIn: const Duration(seconds: 5));
    final dio = buildDio();

    final response = await dio.get('/recipes');

    expect(fakeAuth.refreshCalls, 1);
    expect(response.data, 'Bearer refreshed-access-token');
    expect(adapter.requests.single.headers['Authorization'],
        'Bearer refreshed-access-token');
  });

  test('no refresh token + imminent expiry is still sent as-is', () async {
    await seed(refreshToken: null, expiresIn: const Duration(seconds: 5));
    final dio = buildDio();

    final response = await dio.get('/recipes');

    expect(response.data, 'Bearer live-access-token');
    expect(fakeAuth.refreshCalls, 0);
  });

  test('empty storage rejects the request rather than sending it unauthed',
      () async {
    final dio = buildDio();

    await expectLater(dio.get('/recipes'), throwsA(isA<DioException>()));
    expect(adapter.requests, isEmpty);
  });

  test('a 401 triggers exactly one refresh and replays on retryClient',
      () async {
    await seed();
    adapter.statusQueue.add((_) => 401);
    final dio = buildDio();

    final response = await dio.get('/recipes');

    expect(fakeAuth.refreshCalls, 1);
    expect(adapter.requests, hasLength(1)); // the original 401 only
    expect(retryAdapter.requests, hasLength(1)); // the replay
    expect(retryAdapter.requests.single.headers['Authorization'],
        'Bearer refreshed-access-token');
    expect(response.data, 'Bearer refreshed-access-token');
  });

  test(
      '401 whose grant is rejected clears the session, signs out once, '
      'surfaces the original error', () async {
    await seed();
    adapter.statusQueue.add((_) => 401);
    fakeAuth.failure = const AuthGrantRejectedException();
    var signedOutCalls = 0;
    final dio = buildDio(onSignedOut: () => signedOutCalls++);

    await expectLater(dio.get('/recipes'), throwsA(isA<DioException>()));

    expect(fakeAuth.refreshCalls, 1);
    expect(signedOutCalls, 1);
    expect(retryAdapter.requests, isEmpty);
    expect(await store.read(), isNull);
  });

  test('a refresh that never reaches the server keeps the session', () async {
    await seed(expiresIn: const Duration(seconds: 5));
    fakeAuth.failure = const SocketException('Network is unreachable');
    var signedOutCalls = 0;
    final dio = buildDio(onSignedOut: () => signedOutCalls++);

    // The stale token still goes out; only the response may end the session.
    final response = await dio.get('/recipes');

    expect(response.data, 'Bearer live-access-token');
    expect(signedOutCalls, 0);
    expect((await store.read())?.refreshToken, 'live-refresh-token');
  });

  test('a 401 on a FormData upload is not replayed', () async {
    await seed();
    adapter.statusQueue.add((_) => 401);
    final dio = buildDio();

    await expectLater(
      dio.post('/recipes/x/photo', data: FormData.fromMap({'a': 'b'})),
      throwsA(isA<DioException>()),
    );

    expect(fakeAuth.refreshCalls, 0);
    expect(retryAdapter.requests, isEmpty);
  });

  test('concurrent expiring requests share one refresh', () async {
    await seed(expiresIn: const Duration(seconds: 5));
    // Hold the refresh open until all three requests are inside it, so the
    // assertion pins the coalescing rather than incidental serialisation.
    final gate = Completer<void>();
    fakeAuth.gate = gate;
    final dio = buildDio();

    final pending = Future.wait([
      dio.get('/a'),
      dio.get('/b'),
      dio.get('/c'),
    ]);
    // Let all three reach the refresh. Without coalescing each would call it,
    // so a count of 1 while the gate is shut is the assertion that matters.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fakeAuth.refreshCalls, 1);
    gate.complete();

    final responses = await pending;
    expect(fakeAuth.refreshCalls, 1);
    for (final response in responses) {
      expect(response.data, 'Bearer refreshed-access-token');
    }
  });
}
