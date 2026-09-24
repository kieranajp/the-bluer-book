import '../../domain/recipe.dart';

/// How close a recipe is to being cookable given what's in the pantry.
/// "Have / don't-have" matching: an ingredient counts as had when its key is in
/// the pantry set (see pantryProvider), or when it's a staple — salt and oil
/// are assumed in the cupboard and would otherwise make every recipe look one
/// ingredient short.
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
  final have = recipe.ingredients
      .where((i) => i.detail.isStaple || pantry.contains(i.detail.key))
      .length;
  return Cookability(total: total, have: have);
}
