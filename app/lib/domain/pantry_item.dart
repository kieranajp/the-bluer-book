/// A single ingredient the user has marked as being in their pantry.
/// Presence-only (v1): identified by its (unique) ingredient name.
class PantryItem {
  final String ingredient;
  final DateTime? addedAt;

  const PantryItem({required this.ingredient, this.addedAt});

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    final added = json['addedAt'] as String?;
    return PantryItem(
      ingredient: json['ingredient'] as String,
      addedAt: (added != null && added.isNotEmpty) ? DateTime.tryParse(added) : null,
    );
  }
}
