import 'package:flutter/material.dart';
import 'brand_mark.dart';

/// Animated brand loader — the monogram with a gentle "breathing" pulse.
/// Drop-in for `CircularProgressIndicator` on full-screen / section loads
/// (recipe list initial load, chat "thinking", etc.).
class BrandLoader extends StatefulWidget {
  final double size;
  const BrandLoader({super.key, this.size = 56});

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Transform.scale(
          scale: 0.90 + 0.10 * t, // 0.90 → 1.00
          child: Opacity(opacity: 0.78 + 0.22 * t, child: child),
        );
      },
      child: BrandMark(size: widget.size),
    );
  }
}
