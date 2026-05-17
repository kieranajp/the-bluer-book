import 'package:flutter/material.dart';
import 'colours.dart';

class LabelTone {
  final Color background;
  final Color foreground;

  const LabelTone(this.background, this.foreground);
}

LabelTone labelToneFor(BuildContext context, String type) {
  final c = context.colours;
  switch (type) {
    case 'course':
      return LabelTone(c.primaryContainer, c.onPrimaryContainer);
    case 'cuisine':
      return LabelTone(c.secondaryContainer, c.onSecondaryContainer);
    case 'diet':
      return LabelTone(c.tertiaryContainer, c.onTertiaryContainer);
    case 'method':
      return LabelTone(c.surfaceContainerHigh, c.textPrimary);
    default:
      return LabelTone(c.surfaceContainerHigh, c.textPrimary);
  }
}

String labelDisplayName(String name) =>
    name.replaceAll('_', ' ').replaceAll('-', ' ');
