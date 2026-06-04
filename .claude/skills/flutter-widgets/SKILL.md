---
name: flutter-widgets
description: >-
  Conventions for writing Flutter widgets in the the-bluer-book app (app/lib/).
  Use whenever creating or editing a widget, screen, dialog, section, or sub-widget
  under app/lib/application/. Covers the one-widget-per-file rule (enforced by the
  widget_lint CI check — the build FAILS on violations), file/folder layout and
  naming, extracting widget classes instead of Widget-returning helper methods,
  styling via context.colours / Spacing / TextStyles / Shapes, Riverpod state, and
  freezed domain models.
---

# Writing Flutter widgets in the-bluer-book

The Flutter app lives in `app/lib/`, layered like the backend
(`domain` / `infrastructure` / `application`). UI is in `application/`
(`screens/`, `widgets/`, `styles/`, `providers/`, `utils/`). State is **Riverpod**,
models are **freezed**, HTTP is **Dio**.

> **The build enforces these rules.** Two of them are checked mechanically by
> `app/tool/widget_lint` and run in CI (`.github/workflows/build.yml`). If you
> break them, the **"Flutter: Test" job fails** — code review won't get a chance.
> See `references/widget-lint.md` to run it locally before you push.

## The two lint-enforced rules (non-negotiable)

### 1. One widget class per file
A `lib/**.dart` file holds **at most one** widget class — anything whose superclass
name ends in `Widget` (`StatelessWidget`, `StatefulWidget`, `ConsumerWidget`,
`ConsumerStatefulWidget`, …). A second one — a public sibling **or** a private
`_SubWidget` — fails the build. Extract it to its own file.

(`State<T>` / `ConsumerState<T>` companions and `CustomPainter`s don't count —
they may stay with their widget.)

### 2. No `Widget`-returning helper methods
Only the framework `build` override may return a `Widget`. A `Widget _buildHeader()`
helper fails the build — turn it into a widget class instead. Helpers that return
**non-widgets** (`InputDecoration`, `TextStyle`, `String`, even `List<Widget>`) are
fine; the smell is specifically a method/function that returns a single `Widget`.

```dart
// ❌ fails the lint
Widget _buildHeader(BuildContext context) => Text(title, ...);

// ✅ a widget class in its own file (header.dart)
class Header extends StatelessWidget {
  const Header({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, ...);
}
```

## File & folder layout

- **`widgets/` is flat.** Shared widgets are sibling files; a widget's own
  sub-parts are extracted to **prefixed** sibling files for ownership
  (`recipe_header.dart` → `recipe_source_link.dart`, `recipe_label_chip.dart`).
- **A screen with sub-widgets is a folder** (like `screens/cooking_mode/`):
  `screens/edit_recipe/{edit_recipe_screen.dart, edit_recipe_photo_section.dart, …}`.
  Sub-widget classes are public and **prefixed** with the screen
  (`EditRecipePhotoSection`, `AppShellNavBar`).
- **One class per file, file named after the class** (`StepPage` → `step_page.dart`).
- Promote a sub-widget into the shared flat `widgets/` bucket **only** when
  something outside its owner actually reuses it.

Details and the extraction recipe: `references/file-layout.md`.

## Structure & state (from docs/frontend.md)

- **Screens orchestrate; sections render.** A screen's `build` reads like a table
  of contents — wire providers to a column of section widgets, handle nav/snackbars.
  It does not build form fields or list rows itself.
- **Logic lives in the notifier, not the widget.** Validation, save, CRUD,
  reordering, optimistic toggles → a Riverpod `StateNotifier`. Widgets call
  `notifier.doThing()` and render state.
- **Dialogs and bottom sheets are widgets too** — their own file, shown via
  `showDialog(builder: (_) => const MyDialog())`.
- **Cross-cutting pure helpers go in `utils/`**, not the widget that first needs them.

## Styling — never hardcode colours or sizes

Pull everything from the design system in `application/styles/`:

| Use | For |
|-----|-----|
| `context.colours.primary` (the `Colours` `ThemeExtension`) | every colour |
| `Spacing.xs / s / m / l / xl`, `Spacing.all` | padding & gaps |
| `TextStyles.body(context)`, `.sectionHeading(context)`, … | text |
| `Shapes.squircle(n)`, `Shapes.blob(n)`, `Shapes.tornCorner` | shapes |
| `Decorations.card(context)`, `Decorations.input(context, label)` | containers/fields |

The `ColorScheme` is hand-built — **do not** switch to `ColorScheme.fromSeed`.
More (plus FE↔BE `@JsonKey` bridging and freezed): `references/styling-state-models.md`.

## Before you commit

1. `cd app && flutter analyze` — clean.
2. `cd app/tool/widget_lint && dart pub get && dart run widget_lint` — `ok`.
3. `cd app && flutter test` — green.

See `examples/` for a clean leaf widget, a screen section, and the antipatterns.
