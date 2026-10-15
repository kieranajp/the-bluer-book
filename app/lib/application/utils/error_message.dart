import '../../infrastructure/network/api_exception.dart';

/// Prefers an [ApiException]'s server detail, strips the `Exception: ` prefix
/// from other exceptions, and otherwise (null included) returns [fallback].
String errorMessage(Object? error, {required String fallback}) {
  if (error is ApiException) return error.message;
  if (error is Exception) {
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }
  return fallback;
}
