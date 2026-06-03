import 'dart:ui';

import 'package:flutter/material.dart';
import '../../styles/colours.dart';
import 'app_shell_add_button.dart';
import 'app_shell_nav_item.dart';

/// The floating, blurred bottom navigation bar for the [AppShell].
class AppShellNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onChatTap;

  const AppShellNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.5
                        : 0.12,
                  ),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AppShellNavItem(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Recipes',
                    active: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                ),
                Expanded(
                  child: AppShellNavItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Plan',
                    active: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                  ),
                ),
                const AppShellAddButton(),
                Expanded(
                  child: AppShellNavItem(
                    icon: Icons.kitchen_outlined,
                    label: 'Pantry',
                    active: currentIndex == 2,
                    onTap: () => onTabSelected(2),
                  ),
                ),
                Expanded(
                  child: AppShellNavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    active: false,
                    onTap: onChatTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
