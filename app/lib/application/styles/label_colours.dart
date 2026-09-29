import 'package:flutter/material.dart';
import '../../domain/label.dart';
import 'colours.dart';

class LabelTone {
  final Color background;
  final Color foreground;

  const LabelTone(this.background, this.foreground);
}

/// Each taxonomy type gets a distinct slot of the M3 ladder:
///   course  → primary (denim blue)   — the most prominent type
///   diet    → secondary (sage green) — health/constraint
///   cuisine → tertiary (honey amber) — origin/flavour
///   method  → neutral surface        — least loaded
LabelTone labelToneFor(BuildContext context, String type) {
  final c = context.colours;
  return switch (LabelType.tryParse(type)) {
    LabelType.course => LabelTone(c.primaryContainer, c.onPrimaryContainer),
    LabelType.diet => LabelTone(c.secondaryContainer, c.onSecondaryContainer),
    LabelType.cuisine => LabelTone(c.tertiaryContainer, c.onTertiaryContainer),
    LabelType.method || null => LabelTone(c.surfaceContainerHigh, c.textPrimary),
  };
}

String labelDisplayName(String name) =>
    name.replaceAll('_', ' ').replaceAll('-', ' ');
