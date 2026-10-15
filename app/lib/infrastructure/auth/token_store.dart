import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The tokens one signed-in session holds.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  /// Whether the access token dies within [window]. A session with no recorded
  /// expiry counts as fresh — the 401 path catches it either way.
  bool expiresWithin(Duration window) {
    final at = expiresAt;
    return at != null && at.isBefore(DateTime.now().add(window));
  }
}

/// The session is one JSON value under one key, so a write that fails part-way
/// cannot leave a new access token beside a stale refresh token.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Reachable after the first unlock following a reboot, so a
              // background refresh works on a locked device.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const _sessionKey = 'auth_session';

  final FlutterSecureStorage _storage;

  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final accessToken = json['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) return null;

      final expiresAt = json['expires_at'] as String?;
      return AuthSession(
        accessToken: accessToken,
        refreshToken: json['refresh_token'] as String?,
        expiresAt: expiresAt == null ? null : DateTime.tryParse(expiresAt),
      );
    } catch (_) {
      // Anything unreadable counts as no session; signing in again rewrites it.
      return null;
    }
  }

  Future<void> write(AuthSession session) => _storage.write(
        key: _sessionKey,
        value: jsonEncode({
          'access_token': session.accessToken,
          'refresh_token': session.refreshToken,
          'expires_at': session.expiresAt?.toIso8601String(),
        }),
      );

  Future<void> clear() => _storage.delete(key: _sessionKey);
}
