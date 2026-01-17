import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';

class MealPlanCard extends StatelessWidget {
  final Recipe recipe;

  const MealPlanCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final totalTime = recipe.preparationTime + recipe.cookingTime;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFE0E0E0),
                    image: recipe.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(recipe.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: recipe.imageUrl == null
                      ? const Icon(Icons.restaurant, size: 48, color: Colors.white54)
                      : null,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E6983).withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        recipe.isFavourite ? Icons.star : Icons.star_border,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recipe.name,
              style: GoogleFonts.workSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF121416),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 14,
                  color: Color(0xFF67737E),
                ),
                const SizedBox(width: 4),
                Text(
                  '${totalTime}m',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    color: const Color(0xFF67737E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
