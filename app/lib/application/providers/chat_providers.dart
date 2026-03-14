import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/chat_service.dart';
import 'recipe_providers.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(apiClientProvider));
});

class ChatMessage {
  final String content;
  final bool isUser;
  final bool isComplete;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.isComplete = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({String? content, bool? isComplete}) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser,
      isComplete: isComplete ?? this.isComplete,
      timestamp: timestamp,
    );
  }
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatService _chatService;
  String? _sessionId;
  bool _isStreaming = false;

  ChatNotifier(this._chatService) : super([]);

  bool get isStreaming => _isStreaming;
  String? get sessionId => _sessionId;

  Future<void> sendMessage(String text) async {
    if (_isStreaming || text.trim().isEmpty) return;

    // Add user message
    state = [
      ...state,
      ChatMessage(content: text, isUser: true),
    ];

    // Add empty assistant message
    state = [
      ...state,
      ChatMessage(content: '', isUser: false, isComplete: false),
    ];

    _isStreaming = true;

    try {
      String accumulated = '';

      await for (final event in _chatService.sendMessage(text, sessionId: _sessionId)) {
        if (event.sessionId != null) {
          _sessionId = event.sessionId;
        }

        if (event.content.isNotEmpty) {
          accumulated += event.content;
          // Update the last (assistant) message
          final messages = [...state];
          messages[messages.length - 1] = messages.last.copyWith(
            content: accumulated,
            isComplete: event.done,
          );
          state = messages;
        }

        if (event.done) {
          // Mark complete
          final messages = [...state];
          messages[messages.length - 1] = messages.last.copyWith(isComplete: true);
          state = messages;
        }
      }
    } catch (e, stack) {
      dev.log('Chat error', name: 'ChatNotifier', error: e, stackTrace: stack);
      // Update the last message with error
      final messages = [...state];
      if (messages.isNotEmpty && !messages.last.isUser) {
        messages[messages.length - 1] = messages.last.copyWith(
          content: messages.last.content.isEmpty
              ? 'Sorry, something went wrong. Please try again.'
              : messages.last.content,
          isComplete: true,
        );
        state = messages;
      }
    } finally {
      _isStreaming = false;
    }
  }

  void clearChat() {
    state = [];
    _sessionId = null;
    _isStreaming = false;
  }
}

final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(chatServiceProvider));
});
