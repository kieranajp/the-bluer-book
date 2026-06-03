import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// Striped image placeholder — used when a recipe has no image yet. Matches
/// the Garden Plot mockup atom (45° stripe + tonal overlay).
class StripedPlaceholder extends StatelessWidget {
  final BorderRadius? borderRadius;
  final double? height;
  final double? width;
  final IconData? icon;

  const StripedPlaceholder({
    super.key,
    this.borderRadius,
    this.height,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stripeColor = isDark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.black.withValues(alpha: 0.04);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1, -1),
                  end: const Alignment(1, 1),
                  tileMode: TileMode.repeated,
                  colors: [
                    c.surfaceContainerHigh,
                    c.surfaceContainerHigh,
                    stripeColor,
                    stripeColor,
                  ],
                  stops: const [0.0, 0.5, 0.5, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.primaryContainer.withValues(alpha: 0.45),
                    c.tertiaryContainer.withValues(alpha: 0.25),
                  ],
                ),
                backgroundBlendMode: isDark ? BlendMode.screen : BlendMode.multiply,
              ),
            ),
            if (icon != null)
              Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: c.textSecondary.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
