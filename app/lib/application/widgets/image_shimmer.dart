import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// A subtle sweeping shimmer used as a loading placeholder for images. Sits on
/// top of the same tonal surface as [StripedPlaceholder] so a thumbnail that's
/// still decoding reads as "loading" rather than blinking in and out.
class ImageShimmer extends StatefulWidget {
  final BorderRadius? borderRadius;
  final double? height;
  final double? width;

  const ImageShimmer({
    super.key,
    this.borderRadius,
    this.height,
    this.width,
  });

  @override
  State<ImageShimmer> createState() => _ImageShimmerState();
}

class _ImageShimmerState extends State<ImageShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = c.surfaceContainerHigh;
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [base, highlight, base],
                  stops: const [0.35, 0.5, 0.65],
                  transform: _SweepTransform(_controller.value),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Slides the gradient horizontally across the box from off-screen left to
/// off-screen right as [value] goes 0 → 1.
class _SweepTransform extends GradientTransform {
  final double value;

  const _SweepTransform(this.value);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = (value * 2 - 1) * bounds.width;
    return Matrix4.translationValues(dx, 0, 0);
  }
}
