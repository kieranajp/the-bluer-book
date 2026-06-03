import 'package:flutter/material.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';

/// A single theme-mode row in the [SettingsScreen] appearance section.
class SettingsThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsThemeOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
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
      subtitle: Text(subtitle, style: TextStyles.caption(context)),
      trailing: isSelected
          ? Icon(Icons.check, color: context.colours.primary)
          : null,
      onTap: onTap,
    );
  }
}
