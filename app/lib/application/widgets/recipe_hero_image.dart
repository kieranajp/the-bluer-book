import 'package:flutter/material.dart';
import '../styles/colours.dart';
import 'striped_placeholder.dart';

/// Full-bleed 320px hero with a top-edge dim gradient, glass action chrome
/// (back / share / edit) and a tertiary bookmark FAB anchored bottom-right.
/// Bottom margin overlaps the content sheet by 28px so the sheet appears to
/// peel up into the hero.
class RecipeHeroImage extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback? onBookmark;
  final bool bookmarkActive;

  const RecipeHeroImage({
    super.key,
    required this.imageUrl,
    required this.onBack,
    required this.onShare,
    required this.onEdit,
    this.onBookmark,
    this.bookmarkActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return SizedBox(
      height: 320,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          RecipeImage(
            imageUrl: imageUrl,
            borderRadius: BorderRadius.zero,
            fallbackIcon: Icons.restaurant,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _GlassButton(icon: Icons.arrow_back_rounded, onTap: onBack),
                const Spacer(),
                _GlassButton(icon: Icons.ios_share_rounded, onTap: onShare),
                const SizedBox(width: 8),
                _GlassButton(icon: Icons.edit_outlined, onTap: onEdit),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: -28 + 16, // 16px above the sheet overlap
            child: GestureDetector(
              onTap: onBookmark,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.tertiary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: c.tertiary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  bookmarkActive
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  size: 24,
                  color: c.onTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
