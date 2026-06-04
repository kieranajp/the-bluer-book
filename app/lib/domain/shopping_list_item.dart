/// One line on the shopping list. [source] distinguishes ingredients derived
/// from the meal plan (checking one off stocks the pantry) from free-text
/// custom items the user added or scanned (checking one off just removes it).
class ShoppingListItem {
  final String name;
  final String source;

  const ShoppingListItem({required this.name, required this.source});

  static const sourceMealPlan = 'meal_plan';
  static const sourceCustom = 'custom';

  bool get isCustom => source == sourceCustom;

  /// A custom item the user is adding locally (optimistic UI), before the
  /// server round-trip confirms it.
  const ShoppingListItem.custom(this.name) : source = sourceCustom;

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      name: json['name'] as String,
      source: (json['source'] as String?) ?? sourceMealPlan,
    );
  }
}
