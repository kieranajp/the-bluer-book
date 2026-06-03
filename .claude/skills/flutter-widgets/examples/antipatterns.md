# Antipatterns — what fails the build (and the fix)

Each of these fails the `widget_lint` CI step (`dart run widget_lint`), so the
"Flutter: Test" job goes red.

## ❌ Two widget classes in one file

```dart
// recipe_header.dart
class RecipeHeader extends StatelessWidget { ... }      // primary — fine
class _SourceLink extends StatelessWidget { ... }       // ✗ second widget class
```

> `recipe_header.dart [one-widget-per-file] extra widget class _SourceLink …`

**Fix:** move it to its own file, public + prefixed.

```dart
// recipe_source_link.dart
class RecipeSourceLink extends StatelessWidget { ... }

// recipe_header.dart
import 'recipe_source_link.dart';
// ... uses RecipeSourceLink(...)
```

This applies to **private** `_SubWidget`s too — privacy doesn't exempt them.

## ❌ A `Widget _buildX()` helper method

```dart
class Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _buildRow(context);

  Widget _buildRow(BuildContext context) => Row(children: [...]); // ✗
}
```

> `[widget-returning-method] _buildRow returns Widget; extract it into a widget class`

**Fix:** make `_buildRow` a widget class (in its own file), or inline it. A method
that returns a `Widget` gets no element identity, can't be `const`, and rebuilds
with its parent — which is exactly why it's banned.

### Not flagged (these are fine)

```dart
InputDecoration _decoration(BuildContext c) => Decorations.input(c, label); // ok
String _formatQty(Ingredient i) => '...';                                   // ok
List<Widget> _rows() => [for (...) IngredientRow(...)];                      // ok
@override
Widget build(BuildContext context) => ...;                                   // ok (the override)
```

## ❌ Hardcoded colours / sizes

```dart
Container(color: const Color(0xFF1E2A44), padding: const EdgeInsets.all(16)); // ✗ style
```

Not caught by `widget_lint`, but it's a house-rule reject in review.

**Fix:**

```dart
Container(color: context.colours.primary, padding: Spacing.all);
```

## ❌ Logic in the widget

```dart
// inside a widget's build:
final isValid = name.isNotEmpty && prepTime > 0; // ✗ domain logic in the UI
onPressed: () async { await repo.save(recipe); ... }
```

**Fix:** move validation/save/CRUD into the Riverpod `StateNotifier`; the widget
calls `ref.read(provider.notifier).save()` and renders `ref.watch(provider)`.
