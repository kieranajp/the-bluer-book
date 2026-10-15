import 'package:flutter/material.dart';

/// Garden Plot shape families. Use at most ~3 per screen.
class Shapes {
  Shapes._();

  /// Asymmetric blob: CSS `56% 44% 56% 44% / 44% 56% 44% 56%`.
  static BorderRadius blob(double size) {
    final r1 = size * 0.56;
    final r2 = size * 0.44;
    return BorderRadius.only(
      topLeft: Radius.elliptical(r1, r2),
      topRight: Radius.elliptical(r2, r1),
      bottomRight: Radius.elliptical(r1, r2),
      bottomLeft: Radius.elliptical(r2, r1),
    );
  }

  /// Big top-left and bottom-right corners, tight top-right and bottom-left.
  static const tornCorner = BorderRadius.only(
    topLeft: Radius.circular(36),
    topRight: Radius.circular(14),
    bottomRight: Radius.circular(36),
    bottomLeft: Radius.circular(14),
  );

  /// Smaller torn-corner — for the extended FAB pill.
  static const tornCornerSmall = BorderRadius.only(
    topLeft: Radius.circular(28),
    topRight: Radius.circular(16),
    bottomRight: Radius.circular(28),
    bottomLeft: Radius.circular(16),
  );

  /// Horizontal mirror of [tornCorner]; alternate the two across a grid row so
  /// cards read as a symmetric spread.
  static const tornCornerMirror = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(36),
    bottomRight: Radius.circular(14),
    bottomLeft: Radius.circular(36),
  );

  /// The asymmetric "lift the panel into the hero" corner used on the
  /// details screen content sheet — big top-left, tight top-right.
  static const sheetTop = BorderRadius.only(
    topLeft: Radius.circular(40),
    topRight: Radius.circular(20),
  );

  /// Squircle thumb — recipe rows, ingredient checkboxes.
  static BorderRadius squircle([double r = 22]) => BorderRadius.circular(r);

  /// Diamond-ish — used on the Serves stat icon backdrop.
  static const diamondish = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(28),
    bottomRight: Radius.circular(14),
    bottomLeft: Radius.circular(28),
  );
}
