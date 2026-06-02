import '../../domain/recipe.dart';

/// How close a recipe is to being cookable given what's in the pantry.
/// "Have / don't-have" matching: an ingredient counts as had when its name is
/// in the pantry set (see pantryProvider).
class Cookability {
  final int total;
  final int have;

  const Cookability({required this.total, required this.have});

  int get missing => total - have;

  /// True when the recipe has ingredients and you have all of them.
  bool get ready => total > 0 && have == total;
}

Cookability cookabilityOf(Recipe recipe, Set<String> pantry) {
  final total = recipe.ingredients.length;
  final have =
      recipe.ingredients.where((i) => pantry.contains(i.detail.name)).length;
  return Cookability(total: total, have: have);
}
