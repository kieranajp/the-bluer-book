import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';

/// The Bluer Book brand monogram — an Instrument Serif italic "B" with a sage
/// leaf accent, set in the wonky M3 blob. Drop-in replacement for the 🥦 emoji
/// avatar in the home header (and reusable anywhere a small brand mark fits).
class BrandMark extends StatelessWidget {
  /// Edge length of the square blob, in logical pixels.
  final double size;

  const BrandMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    // The brand sage reads well on both the denim (light) and light-blue (dark)
    // blob, so we pin the leaf to it rather than c.secondary — which inverts to
    // a pale sage in dark mode and disappears against the blob.
    const leafColor = Color(0xFF6B8E5A);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Denim blob plate.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: Shapes.blob(size),
            ),
          ),
          // Instrument Serif italic "B" — nudged a hair left to balance the
          // leaf sitting in the top-right.
          Padding(
            padding: EdgeInsets.only(right: size * 0.06),
            child: Text(
              'B',
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSerif(
                fontSize: size * 0.66,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: c.onPrimary,
              ),
            ),
          ),
          // Sage leaf accent, top-right.
          Positioned(
            top: size * 0.10,
            right: size * 0.12,
            child: Transform.rotate(
              angle: 0.6, // ~34°
              child: CustomPaint(
                size: Size(size * 0.20, size * 0.34),
                painter: _LeafPainter(leafColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _LeafPainter extends CustomPainter {
  final Color color;
  _LeafPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;
    // Almond leaf: pointed top & bottom, bulged sides.
    final path = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w, h * 0.30, w, h * 0.70, w / 2, h)
      ..cubicTo(0, h * 0.70, 0, h * 0.30, w / 2, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.color != color;
}
