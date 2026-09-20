import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/auth/auth_repository.dart';
import '../../infrastructure/auth/token_store.dart';

/// Where the app stands in the sign-in lifecycle. `AuthGate` switches on it.
sealed class AuthState {
  const AuthState();
}

/// Reading the keychain on launch, or waiting on the browser.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

/// Nobody is signed in. [message] says why, when the app arrived here through
/// something going wrong rather than a fresh install.
class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  final String? message;
}

/// A token is in the keychain.
class AuthSignedIn extends AuthState {
  const AuthSignedIn();
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(store: ref.watch(tokenStoreProvider)),
);

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Owns the sign-in lifecycle: resume a stored session on launch, run the
/// browser dance, and fall back to signed-out when the session ends.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthRestoring();
  }

  Future<void> _restore() async {
    final session = await ref.read(tokenStoreProvider).read();
    // A 401 can end the session while this read is still in flight; that
    // verdict is newer than the keychain's, so leave it alone.
    if (state is! AuthRestoring) return;
    state = session == null ? const AuthSignedOut() : const AuthSignedIn();
  }

  Future<void> signIn() async {
    state = const AuthRestoring();
    try {
      await ref.read(authRepositoryProvider).signIn();
      state = const AuthSignedIn();
    } on AuthCancelledException {
      state = const AuthSignedOut();
    } catch (e, stack) {
      dev.log('Sign-in failed',
          name: 'AuthNotifier', error: e, stackTrace: stack);
      state = const AuthSignedOut(message: 'Sign-in failed. Please try again.');
    }
  }

  /// The network layer calls this when a refresh fails. It has already cleared
  /// the tokens, so the gate only has to catch up.
  void sessionEnded() {
    if (state is AuthSignedOut) return;
    state = const AuthSignedOut(
      message: 'Your session expired. Please sign in again.',
    );
  }
}
