import 'package:flutter/material.dart';

/// Shape DNA for the Garden Plot / M3 Expressive design language.
///
/// Used sparingly — max ~3 families per screen. See the design spec card "D"
/// for the full playbook.
class Shapes {
  Shapes._();

  /// Asymmetric blob — wonky avatar / FAB-style. Used on the home header
  /// avatar and the mini filter-blob inside the search pill.
  ///
  /// CSS equivalent: `56% 44% 56% 44% / 44% 56% 44% 56%`
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

  /// Mirror of [blob] — different DNA at the same scale.
  /// CSS equivalent: `44% 56% 44% 56% / 56% 44% 56% 44%`
  static BorderRadius blobMirror(double size) {
    final r1 = size * 0.44;
    final r2 = size * 0.56;
    return BorderRadius.only(
      topLeft: Radius.elliptical(r1, r2),
      topRight: Radius.elliptical(r2, r1),
      bottomRight: Radius.elliptical(r1, r2),
      bottomLeft: Radius.elliptical(r2, r1),
    );
  }

  /// Page-torn-from-the-cookbook corners — big top-left + bottom-right,
  /// tight top-right + bottom-left. Used on meal-plan carousel cards and
  /// the extended "Add to meal plan" FAB.
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
