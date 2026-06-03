import 'package:flutter/material.dart';
import 'image_shimmer.dart';
import 'striped_placeholder.dart';

/// Convenience wrapper: shows the recipe's network image if present, otherwise
/// falls back to a [StripedPlaceholder].
class RecipeImage extends StatelessWidget {
  final String? imageUrl;
  final BorderRadius? borderRadius;
  final double? height;
  final double? width;
  final IconData? fallbackIcon;
  final BoxFit fit;

  const RecipeImage({
    super.key,
    required this.imageUrl,
    this.borderRadius,
    this.height,
    this.width,
    this.fallbackIcon,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(14);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return StripedPlaceholder(
        borderRadius: radius,
        height: height,
        width: width,
        icon: fallbackIcon ?? Icons.restaurant,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        imageUrl!,
        height: height,
        width: width,
        fit: fit,
        // Shimmer while the image streams in, instead of a blank gap.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ImageShimmer(
            borderRadius: radius,
            height: height,
            width: width,
          );
        },
        // Fade freshly-decoded frames in so they don't pop while scrolling.
        // Cache hits load synchronously and skip the fade.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, _, _) => StripedPlaceholder(
          borderRadius: radius,
          height: height,
          width: width,
          icon: fallbackIcon ?? Icons.restaurant,
        ),
      ),
    );
  }
}
