import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/screens/app_shell/app_shell.dart';
import 'application/styles/app_theme.dart';
import 'application/styles/colours.dart';
import 'application/providers/theme_provider.dart';

void main() {
  runApp(const ProviderScope(child: BluerBook()));
}

class BluerBook extends ConsumerWidget {
  const BluerBook({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'The Bluer Book',
      debugShowCheckedModeBanner: false,

      theme: buildAppTheme(Brightness.light, Colours.light),
      darkTheme: buildAppTheme(Brightness.dark, Colours.dark),
      themeMode: themeMode,

      home: const AppShell(),
    );
  }
}
