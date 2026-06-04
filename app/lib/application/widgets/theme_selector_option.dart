import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';

/// A single selectable theme-mode row in the [ThemeSelectorDialog].
class ThemeSelectorOption extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemeSelectorOption({
    super.key,
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
        color: isSelected
            ? context.colours.primary
            : context.colours.textSecondary,
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
