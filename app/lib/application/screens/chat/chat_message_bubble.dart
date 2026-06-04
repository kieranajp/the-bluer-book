import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../providers/chat_providers.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';
import '../../widgets/brand_mark.dart';

/// A single chat message in the [ChatScreen] — a user pill or an assistant
/// markdown bubble (with the brand avatar and a streaming spinner).
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

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
            const BrandMark(size: 32),
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
                  if (isUser)
                    Text(
                      message.content.isEmpty && !message.isComplete
                          ? '...'
                          : message.content,
                      style: TextStyles.body(context).copyWith(
                        color: context.colours.onPrimary,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: message.content.isEmpty && !message.isComplete
                          ? '...'
                          : message.content,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: TextStyles.body(context).copyWith(
                          color: context.colours.textPrimary,
                        ),
                        strong: TextStyles.body(context).copyWith(
                          color: context.colours.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: TextStyles.body(context).copyWith(
                          color: context.colours.textPrimary,
                        ),
                      ),
                      shrinkWrap: true,
                      softLineBreak: true,
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
