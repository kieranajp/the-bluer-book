import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';

/// Uppercase section heading with optional right-aligned action text.
class SectionLabel extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionLabel({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyles.sectionLabel(context),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
