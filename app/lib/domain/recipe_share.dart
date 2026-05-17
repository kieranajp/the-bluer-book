import 'recipe.dart';

extension RecipeShare on Recipe {
  String toShareableText() {
    final buf = StringBuffer()..writeln(name);
    if (description.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(description);
    }

    final stats = <String>[
      if (servings > 0) 'Serves $servings',
      if (preparationTime > 0) 'Prep ${preparationTime}m',
      if (cookingTime > 0) 'Cook ${cookingTime}m',
    ];
    if (stats.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(stats.join(' · '));
    }

    if (ingredients.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Ingredients');
      String? currentComponent;
      for (final ing in ingredients) {
        final component = ing.component ?? '';
        if (component != (currentComponent ?? '') && component.isNotEmpty) {
          currentComponent = component;
          buf
            ..writeln()
            ..writeln('$component:');
        }
        final qty = _formatQty(ing.quantity);
        final unit = ing.unit?.abbreviation ?? ing.unit?.name ?? '';
        final qtyUnit = [qty, unit].where((s) => s.isNotEmpty).join(' ');
        final prep = (ing.preparation?.isNotEmpty ?? false)
            ? ', ${ing.preparation}'
            : '';
        buf.writeln('- ${[qtyUnit, ing.detail.name].where((s) => s.isNotEmpty).join(' ')}$prep');
      }
    }

    if (steps.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Steps');
      for (var i = 0; i < steps.length; i++) {
        buf.writeln('${i + 1}. ${steps[i].description}');
      }
    }

    return buf.toString().trimRight();
  }
}

String _formatQty(double q) {
  if (q == 0) return '';
  if (q == q.roundToDouble()) return q.toInt().toString();
  return q.toString();
}
