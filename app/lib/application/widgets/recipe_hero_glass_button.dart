import 'package:flutter/material.dart';

/// Translucent square icon button used for the [RecipeHeroImage] chrome
/// (back / share / edit).
class RecipeHeroGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const RecipeHeroGlassButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

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
