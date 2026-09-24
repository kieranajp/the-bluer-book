import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';

/// A single removable ingredient chip in the [PantryScreen] inventory.
/// [name] is what's shown; [canonical] is what the pantry is keyed by.
class PantryChip extends ConsumerWidget {
  final String name;
  final String canonical;

  const PantryChip({super.key, required this.name, required this.canonical});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    return InputChip(
      label: Text(name),
      backgroundColor: c.surfaceContainer,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      onDeleted: () =>
          ref.read(pantryProvider.notifier).remove(name, key: canonical),
    );
  }
}
