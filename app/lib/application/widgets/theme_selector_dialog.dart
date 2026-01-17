import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

/// Dialog for selecting app theme mode (System/Light/Dark)
class ThemeSelectorDialog extends ConsumerWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);

    return AlertDialog(
      backgroundColor: context.colours.surface,
      title: Text(
        'Theme',
        style: TextStyles.sectionHeading(context),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: Spacing.s),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            title: 'System',
            subtitle: 'Follow device settings',
            icon: Icons.brightness_auto,
            mode: ThemeMode.system,
            isSelected: currentThemeMode == ThemeMode.system,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.of(context).pop();
            },
          ),
          _ThemeOption(
            title: 'Light',
            subtitle: 'Always use light theme',
            icon: Icons.light_mode,
            mode: ThemeMode.light,
            isSelected: currentThemeMode == ThemeMode.light,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.of(context).pop();
            },
          ),
          _ThemeOption(
            title: 'Dark',
            subtitle: 'Always use dark theme',
            icon: Icons.dark_mode,
            mode: ThemeMode.dark,
            isSelected: currentThemeMode == ThemeMode.dark,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? context.colours.primary : context.colours.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyles.body(context).copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyles.caption(context),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check,
              color: context.colours.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}
