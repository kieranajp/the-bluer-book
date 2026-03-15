import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: context.colours.background,
              elevation: 0,
              title: Text(
                'Settings',
                style: TextStyles.appBarTitle(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.s),
                    Text(
                      'Appearance',
                      style: TextStyles.sectionHeading(context),
                    ),
                    const SizedBox(height: Spacing.s),
                    _ThemeOptionTile(
                      title: 'System',
                      subtitle: 'Follow device settings',
                      icon: Icons.brightness_auto,
                      isSelected: currentThemeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                    _ThemeOptionTile(
                      title: 'Light',
                      subtitle: 'Always use light theme',
                      icon: Icons.light_mode,
                      isSelected: currentThemeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    _ThemeOptionTile(
                      title: 'Dark',
                      subtitle: 'Always use dark theme',
                      icon: Icons.dark_mode,
                      isSelected: currentThemeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: Spacing.bottomSpacer),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
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
