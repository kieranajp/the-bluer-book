import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_providers.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';
import '../../widgets/empty_state.dart';
import 'chat_message_bubble.dart';

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
              padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.s, Spacing.xs, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Ask me about recipes...',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: Spacing.s,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return ChatMessageBubble(message: messages[index]);
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
