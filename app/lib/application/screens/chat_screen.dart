import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatMessagesProvider.notifier).sendMessage(text);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isStreaming = ref.read(chatMessagesProvider.notifier).isStreaming;

    // Scroll to bottom when messages change
    ref.listen(chatMessagesProvider, (_, _) => _scrollToBottom());

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar area
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.xs, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chat',
                      style: TextStyles.appBarTitle(context),
                    ),
                  ),
                  if (messages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'New chat',
                      onPressed: () => ref.read(chatMessagesProvider.notifier).clearChat(),
                    ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48,
                              color: context.colours.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: Spacing.m),
                          Text(
                            'Ask me about recipes...',
                            style: TextStyle(color: context.colours.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: Spacing.s,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _MessageBubble(message: messages[index]);
                      },
                    ),
            ),

            // Input area
            Container(
              padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.xs, Spacing.xs, Spacing.m),
              decoration: BoxDecoration(
                color: context.colours.surface,
                border: Border(
                  top: BorderSide(color: context.colours.border),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyles.searchHint(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: context.colours.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: context.colours.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: context.colours.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Spacing.m,
                            vertical: Spacing.s,
                          ),
                          filled: true,
                          fillColor: context.colours.background,
                        ),
                        style: TextStyles.body(context),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        enabled: !isStreaming,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    IconButton(
                      onPressed: isStreaming ? null : _send,
                      icon: Icon(
                        Icons.send,
                        color: isStreaming
                            ? context.colours.textSecondary.withValues(alpha: 0.4)
                            : context.colours.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.s),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: context.colours.primary,
              child: const Icon(Icons.restaurant, size: 16, color: Colors.white),
            ),
            const SizedBox(width: Spacing.xs),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.m,
                vertical: Spacing.s,
              ),
              decoration: BoxDecoration(
                color: isUser ? context.colours.primary : context.colours.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: context.colours.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content.isEmpty && !message.isComplete
                        ? '...'
                        : message.content,
                    style: TextStyles.body(context).copyWith(
                      color: isUser ? Colors.white : context.colours.textPrimary,
                    ),
                  ),
                  if (!message.isComplete && message.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colours.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }
}
