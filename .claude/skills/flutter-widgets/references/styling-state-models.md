# Styling, state, and domain models

## Styling: use the design system, never hardcode

Everything visual comes from `app/lib/application/styles/`. Hardcoded colours or
sizes are a review reject (and against the house rules in `AGENTS.md`).

### Colours — `context.colours`
A `Colours` `ThemeExtension`, reached via the `BuildContext` extension:

```dart
final c = context.colours;
Container(color: c.surfaceContainer, child: Icon(..., color: c.primary));
```

Common fields: `background`, `surface`, `surfaceContainer(High/Highest/…)`,
`primary` / `onPrimary` / `primaryContainer` / `onPrimaryContainer`, and the same
for `secondary` / `tertiary`, plus `textPrimary`, `textSecondary`, `outlineVariant`,
`border`, `shadow`.

**The `ColorScheme` is hand-built — do not switch to `ColorScheme.fromSeed`.**

### Spacing — `Spacing`
`Spacing.xs (8) / s (12) / m (16) / l (24) / xl (32)`, plus named sizes
(`bottomSpacer`, `mealPlanImageHeight`, …) and ready EdgeInsets
(`Spacing.all`, `Spacing.horizontal`, `Spacing.vertical`).

### Text — `TextStyles`
Context-aware factories: `TextStyles.body(context)`, `.sectionHeading(context)`,
`.caption(context)`, `.appBarTitle(context)`, `.recipeTitle(context)`,
`.serifCardTitle(context)`, `.cardSubtitle(context)`, `.tag(context)`, …
Tweak with `.copyWith(...)` rather than building a `TextStyle` from scratch.

### Shapes — `Shapes`
`Shapes.squircle(radius)`, `Shapes.blob(size)`, `Shapes.tornCorner`,
`Shapes.sheetTop`, `Shapes.diamondish`.

### Decorations — `Decorations`
`Decorations.card(context)` for card containers, `Decorations.input(context, label)`
for form-field `InputDecoration`. A helper returning an `InputDecoration` /
`TextStyle` is fine (it's not a `Widget`).

## State: Riverpod

- Read/watch providers in `build`; never store derived domain data on a widget.
- **Logic belongs in a `StateNotifier`** (`EditRecipeNotifier`, `RecipeListNotifier`,
  the pantry notifier). Widgets call `ref.read(provider.notifier).doThing()` and
  render `ref.watch(provider)`.
- `ConsumerWidget` / `ConsumerStatefulWidget` for widgets that need `ref`; plain
  `StatelessWidget` / `StatefulWidget` otherwise. A sub-widget should take the data
  it needs as constructor params and stay as "dumb" as possible — push reads up to
  the screen/section unless the sub-widget genuinely owns the interaction.

## Domain models: freezed + json_serializable

Models live in `app/lib/domain/` as `@freezed` immutable classes with
`fromJson`/`toJson`. The generated `*.freezed.dart` / `*.g.dart` are committed but
are **outputs** — after editing a model, run:

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

**FE↔BE field names differ by design.** The Flutter domain bridges names with
`@JsonKey` (e.g. `preparationTime` ↔ `prepTime`, `cookingTime` ↔ `cookTime`). If a
Go JSON struct tag changes, update the matching `@JsonKey` in `app/lib/domain`.
(`invalid_annotation_target` is intentionally ignored in `analysis_options.yaml`
for these.)
