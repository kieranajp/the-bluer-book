import 'package:flutter/material.dart';
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
  switch (type) {
    case 'course':
      return LabelTone(c.primaryContainer, c.onPrimaryContainer);
    case 'diet':
      return LabelTone(c.secondaryContainer, c.onSecondaryContainer);
    case 'cuisine':
      return LabelTone(c.tertiaryContainer, c.onTertiaryContainer);
    case 'method':
      return LabelTone(c.surfaceContainerHigh, c.textPrimary);
    default:
      return LabelTone(c.surfaceContainerHigh, c.textPrimary);
  }
}

String labelDisplayName(String name) =>
    name.replaceAll('_', ' ').replaceAll('-', ' ');
