import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tab_provider.dart';
import '../styles/colours.dart';
import 'chat_screen.dart';
import 'edit_recipe_screen.dart';
import 'meal_plan_screen.dart';
import 'pantry_screen.dart';
import 'recipe_list_screen.dart';
import 'settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  void _selectTab(int i) {
    ref.read(selectedTabProvider.notifier).state = i;
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(selectedTabProvider);

    final tabs = [
      const RecipeListScreen(),
      const MealPlanScreen(),
      const PantryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: tabs),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingNavBar(
              currentIndex: currentIndex,
              onTabSelected: _selectTab,
              onChatTap: _openChat,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onChatTap;

  const _FloatingNavBar({
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
                  child: _NavItem(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Recipes',
                    active: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Plan',
                    active: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                  ),
                ),
                _AddButton(),
                Expanded(
                  child: _NavItem(
                    icon: Icons.kitchen_outlined,
                    label: 'Pantry',
                    active: currentIndex == 2,
                    onTap: () => onTabSelected(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    active: false,
                    onTap: onChatTap,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    active: currentIndex == 3,
                    onTap: () => onTabSelected(3),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final color = active ? c.onSecondaryContainer : c.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: c.primary.withValues(alpha: 0.33),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditRecipeScreen()),
          ),
          child: Container(
            width: 56,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.33),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, size: 24, color: c.onPrimary),
          ),
        ),
      ),
    );
  }
}
