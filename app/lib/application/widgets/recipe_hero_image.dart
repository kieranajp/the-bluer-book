import 'package:flutter/material.dart';
import '../styles/colours.dart';

class RecipeHeroImage extends StatelessWidget {
  final String? imageUrl;

  const RecipeHeroImage({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Recipe image
        imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
              )
            : Container(
                color: context.colours.border,
                child: Icon(
                  Icons.restaurant,
                  size: 64,
                  color: context.colours.textSecondary.withValues(alpha: 0.5),
                ),
              ),

        // Gradient overlay for better readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // TODO: Video play button overlay when video_url is added to model
      ],
    );
  }
}
