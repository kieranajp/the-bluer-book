# File & folder layout

Where a widget class lives, how it's named, and how to split one file into many
without breaking the build.

## Naming

- **One public widget class per file**, file named after the class in snake_case:
  `RecipeStatCell` → `recipe_stat_cell.dart`.
- **Prefix sub-widgets with their owner** so ownership is obvious and names don't
  collide (Dart privacy is per-file, so an extracted sub-widget becomes *public*):
  - `recipe_header.dart`'s parts → `RecipeSourceLink`, `RecipeLabelChip`
  - `recipe_stats_card.dart`'s parts → `RecipeStatCell`, `RecipeStatDivider`
  - `screens/app_shell/`'s parts → `AppShellNavBar`, `AppShellNavItem`, `AppShellAddButton`
- A model/data class in a widget file (e.g. `FilterOption` in `filter_chip_row.dart`)
  is fine — the lint only counts **widget** classes.

## `widgets/` is flat

`app/lib/application/widgets/` is the shared, flat bucket. A widget's own
sub-parts are extracted as **sibling files** in the same directory, prefixed with
the owner. Don't make a folder per widget here.

```
widgets/
  recipe_header.dart          # RecipeHeader (imports the two below)
  recipe_source_link.dart     # RecipeSourceLink
  recipe_label_chip.dart      # RecipeLabelChip
```

Only promote a sub-widget to a top-level shared widget when something **outside
its owner** reuses it (e.g. `RecipeImage`, `BrandLoader` are used across screens,
so they're their own files imported widely).

## Screens with sub-widgets are folders

A screen that grows sub-widgets becomes a folder named after the feature (the
established pattern is `screens/cooking_mode/`):

```
screens/edit_recipe/
  edit_recipe_screen.dart           # EditRecipeScreen — the entry point
  edit_recipe_photo_section.dart    # EditRecipePhotoSection
  edit_recipe_basic_info_section.dart
  edit_recipe_details_section.dart
  edit_recipe_ingredients_section.dart
  edit_recipe_steps_section.dart
  edit_recipe_labels_section.dart
  edit_recipe_form_field.dart       # shared within the folder
```

Sub-widget classes are **public** and prefixed with the screen name.

### Import depth gotcha

`domain/` lives at `app/lib/domain/`, **not** under `application/`. From a
screen file the relative path changes with folder depth:

| File location | import of `domain/recipe.dart` |
|---------------|--------------------------------|
| `application/screens/foo_screen.dart` (flat) | `../../domain/recipe.dart` |
| `application/screens/foo/foo_screen.dart` (folder) | `../../../domain/recipe.dart` |
| `application/widgets/foo.dart` | `../../domain/recipe.dart` |

`providers/`, `styles/`, `widgets/` *are* under `application/`, so from a screen
folder they're `../../providers/…`, `../../styles/…`, `../../widgets/…`.
`flutter analyze` catches a wrong level immediately — run it.

## Recipe: splitting a file that has >1 widget class

1. Decide the **primary** class (the one matching the filename / the screen entry
   point). It stays put.
2. For each extra class, create a new file:
   - flat sibling in `widgets/`, or a file in the screen's folder;
   - rename it public + prefixed (`_StatCell` → `RecipeStatCell`);
   - give it `const` constructor + `super.key` if it had none.
   - copy any private helpers it used (e.g. `_qty`, `_name`) along with it.
3. In the primary file: add the `import` and update references to the new name.
4. If you moved a **public** widget that other files imported, update those
   importers (`grep -rl OldClassName lib`). Private `_` widgets have no external
   importers.
5. `flutter analyze` (catches broken/unused imports), then `dart run widget_lint`.

## Beyond widgets: one concept per file

The widget rule ("one widget class per file") is the strict, lint-enforced case of a
broader convention borrowed from PSR-1/PSR-4: **a file holds one concept, named after
it.** Outside `widgets/`/`screens/`, "one concept" is broader than one class, and the
codebase is consistent about it:

| Layer | One file holds | Example |
|-------|----------------|---------|
| `widgets/`, `screens/` | one **widget class** (strict, lint-enforced) | `recipe_stat_cell.dart` → `RecipeStatCell` |
| `domain/` | an aggregate **+ its value objects** | `ingredient.dart` → `Ingredient`, `IngredientDetail`, `IngredientUnit` |
| `providers/` | a notifier **+ its state** | `chat_providers.dart` → `ChatNotifier`, `ChatMessage` |
| `infrastructure/` | a client **+ its result/event type** | `recipe_repository.dart` → `RecipeRepository`, `PaginatedRecipes` |

The test is **cohesion**: a value object that only describes its aggregate (or the state
a notifier owns) belongs with it; an unrelated class gets its own file. The directory
mirrors the layering (`domain` / `application` / `infrastructure`), and the file shares
its name with the primary type. So don't split a `freezed` state class out of its
notifier, or a value object out of its aggregate, just to chase "one class per file" —
that rule is specifically for widgets.

## File size

Aim for small files — a couple hundred lines. Past **~300 lines** a Dart file is almost
always doing too much; treat it as a prompt to find a seam: extract widgets (per the
rule above), pull pure helpers into `utils/`, or move logic into a notifier. A few files
legitimately run longer (design tokens, a cohesive notifier). This is a review
guideline, **not** a CI gate — but it's usually how you discover an SRP violation before
the widget lint does.
