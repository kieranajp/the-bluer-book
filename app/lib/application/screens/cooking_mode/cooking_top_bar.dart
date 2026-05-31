import 'package:flutter/material.dart';

import '../../styles/colours.dart';

/// Top bar: close, title, gesture toggle.
class CookingTopBar extends StatelessWidget {
  final String title;
  final bool gesturesEnabled;
  final VoidCallback onToggleGestures;
  final VoidCallback onClose;

  const CookingTopBar({
    super.key,
    required this.title,
    required this.gesturesEnabled,
    required this.onToggleGestures,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: c.textSecondary,
            tooltip: 'Exit cooking mode',
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onToggleGestures,
            isSelected: gesturesEnabled,
            icon: const Icon(Icons.front_hand_outlined),
            selectedIcon: const Icon(Icons.front_hand_rounded),
            color: c.textSecondary,
            style: IconButton.styleFrom(
              backgroundColor:
                  gesturesEnabled ? c.secondaryContainer : Colors.transparent,
              foregroundColor:
                  gesturesEnabled ? c.onSecondaryContainer : c.textSecondary,
            ),
            tooltip: gesturesEnabled
                ? 'Hand gestures on'
                : 'Turn on hand gestures',
          ),
        ],
      ),
    );
  }
}
