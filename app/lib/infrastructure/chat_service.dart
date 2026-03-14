import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'network/api_client.dart';

class ChatEvent {
  final String content;
  final bool done;
  final String? sessionId;

  ChatEvent({required this.content, required this.done, this.sessionId});

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    return ChatEvent(
      content: json['content'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      sessionId: json['session_id'] as String?,
    );
  }
}

class ChatService {
  final ApiClient _apiClient;

  ChatService(this._apiClient);

  Stream<ChatEvent> sendMessage(String message, {String? sessionId}) async* {
    final response = await _apiClient.dio.post(
      '/chat',
      data: {
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);

      // Parse SSE data lines
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final block = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);

        for (final line in block.split('\n')) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield ChatEvent.fromJson(json);
            } catch (_) {
              // Skip malformed events
            }
          }
        }
      }
    }
  }
}
