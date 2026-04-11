import '../../domain/ingredient.dart';

/// A segment of step text, either plain or linked to an ingredient.
class HighlightSegment {
  final String text;
  final Ingredient? ingredient;

  const HighlightSegment(this.text, {this.ingredient});

  bool get isHighlighted => ingredient != null;
}

/// Scans [text] for mentions of ingredient names from [ingredients] and
/// returns a list of segments splitting the text into plain and highlighted
/// parts. Matching is case-insensitive with word boundaries, and handles
/// basic English pluralisation (egg/eggs, tomato/tomatoes, cherry/cherries).
///
/// Ingredients with longer names are matched first so that "soy sauce" takes
/// priority over "soy".
List<HighlightSegment> highlightIngredients(
  String text,
  List<Ingredient> ingredients,
) {
  if (text.isEmpty || ingredients.isEmpty) {
    return [HighlightSegment(text)];
  }

  // Build (pattern, ingredient) pairs sorted longest-name-first.
  final entries = <_PatternEntry>[];
  for (final ingredient in ingredients) {
    final name = ingredient.detail.name;
    if (name.isEmpty) continue;

    final variants = _pluralVariants(name);
    // Escape each variant for regex, join with |
    final alternation =
        variants.map((v) => RegExp.escape(v)).join('|');
    final pattern = RegExp(
      '\\b($alternation)\\b',
      caseSensitive: false,
    );
    entries.add(_PatternEntry(pattern, ingredient, name.length));
  }

  // Sort longest name first so multi-word ingredients match before their
  // sub-parts (e.g. "soy sauce" before "soy").
  entries.sort((a, b) => b.nameLength.compareTo(a.nameLength));

  // Build a single combined regex from all entries so we can walk the string
  // once.  Each entry becomes a named group so we can identify which
  // ingredient matched.
  final groupNames = <String, Ingredient>{};
  final groupPatterns = <String>[];
  for (var i = 0; i < entries.length; i++) {
    final groupName = 'g$i';
    final variants = _pluralVariants(entries[i].ingredient.detail.name);
    final alternation =
        variants.map((v) => RegExp.escape(v)).join('|');
    groupPatterns.add('(?<$groupName>\\b(?:$alternation)\\b)');
    groupNames[groupName] = entries[i].ingredient;
  }

  final combined = RegExp(
    groupPatterns.join('|'),
    caseSensitive: false,
  );

  final segments = <HighlightSegment>[];
  var cursor = 0;

  for (final match in combined.allMatches(text)) {
    // Add any plain text before this match.
    if (match.start > cursor) {
      segments.add(HighlightSegment(text.substring(cursor, match.start)));
    }

    // Identify which ingredient matched via named groups.
    Ingredient? matched;
    for (final entry in groupNames.entries) {
      if (match.namedGroup(entry.key) != null) {
        matched = entry.value;
        break;
      }
    }

    segments.add(HighlightSegment(match.group(0)!, ingredient: matched));
    cursor = match.end;
  }

  // Trailing plain text.
  if (cursor < text.length) {
    segments.add(HighlightSegment(text.substring(cursor)));
  }

  return segments;
}

/// Returns a set of singular/plural variants for [name].
Set<String> _pluralVariants(String name) {
  final lower = name.toLowerCase();
  final variants = <String>{name};

  // Already plural ending in "ies" → add "y" singular (cherries → cherry)
  if (lower.endsWith('ies')) {
    variants.add('${name.substring(0, name.length - 3)}y');
  }
  // Already plural ending in "es" → add base without "es" (tomatoes → tomato)
  else if (lower.endsWith('es')) {
    variants.add(name.substring(0, name.length - 2));
  }
  // Already plural ending in "s" (but not "ss") → add base without "s"
  else if (lower.endsWith('s') && !lower.endsWith('ss')) {
    variants.add(name.substring(0, name.length - 1));
  }

  // Singular ending in "y" (not preceded by vowel) → add "ies"
  if (lower.endsWith('y') &&
      lower.length > 1 &&
      !'aeiou'.contains(lower[lower.length - 2])) {
    variants.add('${name.substring(0, name.length - 1)}ies');
  }

  // Add simple "s" and "es" plurals
  if (!lower.endsWith('s')) {
    variants.add('${name}s');
    variants.add('${name}es');
  }

  return variants;
}

class _PatternEntry {
  final RegExp pattern;
  final Ingredient ingredient;
  final int nameLength;

  _PatternEntry(this.pattern, this.ingredient, this.nameLength);
}

/// Formats an ingredient for tooltip display (e.g. "200g flour, sifted").
String formatIngredientTooltip(Ingredient ingredient) {
  final buffer = StringBuffer();

  if (ingredient.quantity > 0) {
    if (ingredient.quantity == ingredient.quantity.toInt()) {
      buffer.write(ingredient.quantity.toInt());
    } else {
      buffer.write(ingredient.quantity);
    }
  }

  if (ingredient.unit != null) {
    final unitText = ingredient.unit!.abbreviation?.isNotEmpty == true
        ? ingredient.unit!.abbreviation!
        : ingredient.unit!.name.isNotEmpty
            ? ingredient.unit!.name
            : null;
    if (unitText != null) {
      buffer.write(' $unitText');
    }
  }

  buffer.write(' ${ingredient.detail.name}');

  if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) {
    buffer.write(', ${ingredient.preparation}');
  }

  return buffer.toString().trim();
}
