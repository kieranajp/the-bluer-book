import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SessionStorage wraps the platform keychain / encrypted shared prefs
/// behind a single API. Holds the Kratos session token so the device
/// stays signed in across launches without a fresh OIDC dance each time.
class SessionStorage {
  static const _tokenKey = 'kratos_session_token';

  static const _options = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  static const _androidOptions = AndroidOptions(encryptedSharedPreferences: true);

  final FlutterSecureStorage _storage;

  SessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: _options,
              aOptions: _androidOptions,
            );

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
