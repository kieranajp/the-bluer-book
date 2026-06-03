import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import 'package:app/application/styles/app_theme.dart';
import 'package:app/application/styles/colours.dart';

/// A [GoldenTestScenario] that renders [child] under the app's real shipping
/// theme ([buildAppTheme]) for the given [brightness], on the matching
/// background colour. Use this so goldens reflect production theming — the
/// hand-built `ColorScheme` and the `Colours` extension that widgets read via
/// `context.colours` — rather than a bare `ThemeData.light`.
GoldenTestScenario themedScenario({
  required String name,
  required Brightness brightness,
  required Widget child,
}) {
  final colours = brightness == Brightness.light ? Colours.light : Colours.dark;
  return GoldenTestScenario(
    name: name,
    child: Theme(
      data: buildAppTheme(brightness, colours),
      child: ColoredBox(
        color: colours.background,
        // A Material ancestor keeps widgets that expect one (ink, tooltips,
        // default text styling) happy without changing the rendered surface.
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    ),
  );
}
