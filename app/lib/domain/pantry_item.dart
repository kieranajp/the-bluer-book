import 'ingredient.dart';

/// A single ingredient the user has marked as being in their pantry.
/// Presence-only (v1).
class PantryItem {
  final String ingredient;
  final String? canonical;
  final DateTime? addedAt;

  const PantryItem({required this.ingredient, this.canonical, this.addedAt});

  /// What to compare on when deciding whether a recipe's ingredient is in
  /// stock. See [IngredientDetail.key] — [ingredient] is for display.
  String get key => canonical ?? ingredientKey(ingredient);

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    final added = json['addedAt'] as String?;
    return PantryItem(
      ingredient: json['ingredient'] as String,
      canonical: json['canonical'] as String?,
      addedAt: (added != null && added.isNotEmpty) ? DateTime.tryParse(added) : null,
    );
  }
}
