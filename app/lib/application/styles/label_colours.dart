import 'package:flutter/material.dart';
import '../../domain/label.dart';
import 'colours.dart';

class LabelTone {
  final Color background;
  final Color foreground;

  const LabelTone(this.background, this.foreground);
}

/// Course → primary, diet → secondary, cuisine → tertiary, method → neutral
/// surface: each taxonomy type gets its own slot of the M3 ladder.
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
