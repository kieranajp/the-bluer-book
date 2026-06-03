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
