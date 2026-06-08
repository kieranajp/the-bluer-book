import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';
import 'settings_account_section.dart';
import 'settings_theme_option_tile.dart';

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
                    SettingsThemeOptionTile(
                      title: 'System',
                      subtitle: 'Follow device settings',
                      icon: Icons.brightness_auto,
                      isSelected: currentThemeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                    SettingsThemeOptionTile(
                      title: 'Light',
                      subtitle: 'Always use light theme',
                      icon: Icons.light_mode,
                      isSelected: currentThemeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    SettingsThemeOptionTile(
                      title: 'Dark',
                      subtitle: 'Always use dark theme',
                      icon: Icons.dark_mode,
                      isSelected: currentThemeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                    const SizedBox(height: Spacing.l),
                    const SettingsAccountSection(),
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
