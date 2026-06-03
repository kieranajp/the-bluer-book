import 'package:dio/dio.dart';

/// A typed error for failed API calls.
///
/// Carries the HTTP status, the server's error `code`/`message` (parsed from the
/// API's `{"error": {"code": ..., "message": ...}}` envelope) and the action we
/// were attempting, so the UI can show a real reason — or branch on the *kind*
/// of failure — instead of matching on strings.
class ApiException implements Exception {
  ApiException({
    required this.action,
    this.statusCode,
    this.code,
    this.serverMessage,
    this.dioType,
    this.cause,
  });

  /// What we were trying to do, e.g. "Failed to save recipe".
  final String action;

  /// HTTP status code, or null when the request never got a response
  /// (offline, timeout, connection refused, …).
  final int? statusCode;

  /// Server error code from the response body, e.g. "invalid_json".
  final String? code;

  /// Human-readable message from the response body, if the server sent one.
  final String? serverMessage;

  /// Transport failure type when there was no HTTP response.
  final DioExceptionType? dioType;

  /// The underlying error, kept for logging.
  final Object? cause;

  /// True when the request never received an HTTP response.
  bool get isNetworkError => statusCode == null;

  /// True for 4xx responses — usually something the user/input can fix.
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// True for 5xx responses — a server-side failure.
  bool get isServerError => statusCode != null && statusCode! >= 500;

  bool get isNotFound => statusCode == 404;

  /// A user-facing message: the action plus the most specific detail available.
  String get message {
    if (statusCode != null) {
      if (serverMessage != null && serverMessage!.isNotEmpty) {
        final suffix = code != null && code!.isNotEmpty ? ' [$code]' : '';
        return '$action ($statusCode): $serverMessage$suffix';
      }
      return '$action ($statusCode)';
    }
    if (dioType != null) {
      return '$action (${dioType!.name})';
    }
    return action;
  }

  @override
  String toString() => message;

  /// Builds an [ApiException] from a Dio failure, pulling the error `code` and
  /// `message` out of the server's response envelope when present.
  factory ApiException.fromDio(String action, DioException e) {
    final response = e.response;
    String? code;
    String? serverMessage;

    final data = response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final m = error['message'];
        if (m is String && m.isNotEmpty) serverMessage = m;
        final c = error['code'];
        if (c is String && c.isNotEmpty) code = c;
      }
      if (serverMessage == null) {
        final m = data['message'];
        if (m is String && m.isNotEmpty) serverMessage = m;
      }
    } else if (data is String && data.isNotEmpty) {
      serverMessage = data;
    }

    return ApiException(
      action: action,
      statusCode: response?.statusCode,
      code: code,
      serverMessage: serverMessage,
      dioType: response == null ? e.type : null,
      cause: e,
    );
  }
}
