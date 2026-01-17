import 'package:flutter/material.dart';

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
                color: const Color(0xFFE0E0E0),
                child: const Icon(
                  Icons.restaurant,
                  size: 64,
                  color: Colors.white54,
                ),
              ),

        // Gradient overlay for better readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
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
