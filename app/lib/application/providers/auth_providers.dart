import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/me.dart';
import '../../infrastructure/auth/kratos_auth_client.dart';
import '../../infrastructure/auth/session_storage.dart';
import '../../infrastructure/me_repository.dart';
import '../../infrastructure/network/api_client.dart';

/// AuthState captures where we are in the sign-in lifecycle. The
/// AuthGate widget switches on this to decide what to render.
sealed class AuthState {
  const AuthState();
}

/// Initial pass: we're trying the persisted Kratos session token, if
/// any, against /api/me. The gate shows a splash spinner.
class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

/// No usable session — render the login screen.
class AuthStateSignedOut extends AuthState {
  /// Optional message to show on the login screen, e.g. after a
  /// failed sign-in attempt.
  final String? error;
  const AuthStateSignedOut({this.error});
}

/// Session valid, /api/me succeeded. Render the app shell.
class AuthStateSignedIn extends AuthState {
  final Me me;
  const AuthStateSignedIn(this.me);
}

/// SessionStorage is its own provider so widgets / repos can grab the
/// same instance without re-instantiating the secure-storage handle.
final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());

/// The KratosAuthClient is stateless; one shared instance is fine.
final kratosAuthClientProvider =
    Provider<KratosAuthClient>((ref) => KratosAuthClient());

/// Single shared ApiClient. Lives in the auth-providers file because
/// it knows how to call back to [AuthNotifier] on 401 — every other
/// provider (recipes, pantry, …) reads this same instance.
///
/// The callback uses `ref.read` so the AuthNotifier lookup happens at
/// invocation time rather than construction time, avoiding the
/// construction-order cycle (ApiClient → onUnauthenticated → AuthNotifier
/// → MeRepository → ApiClient).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    sessionStorage: ref.read(sessionStorageProvider),
    onUnauthenticated: () {
      ref.read(authProvider.notifier).notifySessionInvalidated();
    },
  );
});

final meRepositoryProvider = Provider<MeRepository>(
  (ref) => MeRepository(ref.read(apiClientProvider)),
);

/// AuthNotifier owns the AuthState and the side-effects that move
/// between its variants:
///   - on startup, attempt to validate a persisted session via /api/me
///   - signInWithGoogle() runs the Kratos OIDC dance and writes the
///     returned session token to secure storage
///   - signOut() clears local state (and asks the backend / Kratos to
///     forget the session — best-effort)
///
/// The 401 path in AuthInterceptor calls notifySessionInvalidated()
/// so a rejected request kicks the user back to the login screen.
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  late SessionStorage _storage;
  late KratosAuthClient _kratos;
  late MeRepository _me;

  @override
  AuthState build() {
    _storage = ref.read(sessionStorageProvider);
    _kratos = ref.read(kratosAuthClientProvider);
    _me = ref.read(meRepositoryProvider);
    // Kick off the initial session check.
    Future.microtask(_attemptResumeSession);
    return const AuthStateLoading();
  }

  Future<void> _attemptResumeSession() async {
    final token = await _storage.read();
    if (token == null || token.isEmpty) {
      state = const AuthStateSignedOut();
      return;
    }
    try {
      final me = await _me.fetchMe();
      state = AuthStateSignedIn(me);
    } catch (e) {
      dev.log('Resume session failed: $e', name: 'AuthNotifier');
      await _storage.clear();
      state = const AuthStateSignedOut();
    }
  }

  /// Runs the Kratos OIDC dance and, on success, stores the token and
  /// flips to signed-in. Surfaces a user-friendly error on the login
  /// screen if anything in the chain fails.
  Future<void> signInWithGoogle() async {
    state = const AuthStateLoading();
    try {
      final token = await _kratos.signInWithGoogle();
      await _storage.write(token);
      final me = await _me.fetchMe();
      state = AuthStateSignedIn(me);
    } catch (e) {
      dev.log('signInWithGoogle failed: $e', name: 'AuthNotifier');
      await _storage.clear();
      state = AuthStateSignedOut(error: _readableError(e));
    }
  }

  /// Drops local session state immediately. Backend-side, the session
  /// gets revoked the next time it's introspected (or after expiry);
  /// we don't bother round-tripping to Kratos here since the user just
  /// wants the app to stop talking to it.
  Future<void> signOut() async {
    await _storage.clear();
    state = const AuthStateSignedOut();
  }

  /// Public entry-point for AuthInterceptor: a 401 from any API call
  /// means the session is no longer valid. Drops the user to the
  /// login screen with a "your session expired" message. Already-
  /// signed-out states are left alone.
  void notifySessionInvalidated() {
    if (state is! AuthStateSignedIn) return;
    state = const AuthStateSignedOut(
      error: 'Your session has expired. Please sign in again.',
    );
  }

  String _readableError(Object e) {
    if (e is KratosAuthException) return e.message;
    return 'Sign-in failed. Please try again.';
  }
}
