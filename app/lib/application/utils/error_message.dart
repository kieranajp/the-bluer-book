import '../../infrastructure/network/api_exception.dart';

/// Returns a user-facing message for [error].
///
/// Prefers a typed [ApiException]'s detail (which includes the server's reason),
/// strips the noisy `Exception: ` prefix off any other [Exception], and falls
/// back to [fallback] for anything unrecognised (or null).
String errorMessage(Object? error, {required String fallback}) {
  if (error is ApiException) return error.message;
  if (error is Exception) {
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }
  return fallback;
}
