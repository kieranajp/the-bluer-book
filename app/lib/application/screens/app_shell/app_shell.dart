import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tab_provider.dart';
import '../chat/chat_screen.dart';
import '../meal_plan_screen.dart';
import '../pantry/pantry_screen.dart';
import '../recipe_list_screen.dart';
import 'app_shell_nav_bar.dart';

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
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: tabs),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppShellNavBar(
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
