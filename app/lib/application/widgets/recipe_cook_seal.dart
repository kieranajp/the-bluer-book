import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../utils/cookability.dart';

/// Place inside a [Stack] under a [Positioned] with small negative insets so it
/// overlaps the thumbnail corner.
class RecipeCookSeal extends StatelessWidget {
  final Cookability cook;

  const RecipeCookSeal({super.key, required this.cook});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final ready = cook.ready;
    // Ready pops in sage "go" green; a still-missing recipe recedes into a
    // neutral seal carrying the count of ingredients you're short.
    final bg = ready ? c.secondary : c.surfaceContainerHighest;
    final fg = ready ? c.onSecondary : c.textSecondary;
    return Semantics(
      label: ready ? 'Ready to cook' : 'Missing ${cook.missing} ingredients',
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          // Ring in the card background colour so the seal reads as cut out
          // from the image, lifting it off whatever's behind.
          border: Border.all(color: c.background, width: 2),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: ready
            ? Icon(Icons.check_rounded, size: 13, color: fg)
            : Text(
                '${cook.missing}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
