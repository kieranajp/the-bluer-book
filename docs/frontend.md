# Frontend patterns (Flutter)

The app mirrors the backend's layering under `app/lib/`:

```
app/lib/
├── domain/                   # immutable models (freezed + json_serializable)
├── infrastructure/           # the outside world
│   ├── network/              #   ApiClient (Dio) + AuthInterceptor
│   ├── recipe_repository.dart#   the only place HTTP lives
│   ├── chat_service.dart     #   SSE client for /api/chat
│   └── config/               #   ApiConfig, OAuthConfig
└── application/              # UI + state
    ├── providers/            #   Riverpod
    ├── screens/ widgets/
    ├── styles/               #   Colours, Spacing, TextStyles, Shapes
    └── utils/
```

State management is **Riverpod**; HTTP is **Dio**; models are **freezed**.

## Keeping widgets small (the rule that matters most here)

Flutter tutorials happily let a screen grow into a 1000-line `build` method. We don't.
Five rules keep the UI readable — follow them when you touch it.

### 1. One widget class per file

This is a hard preference here: **one public widget class to a file**, named after the
file (`step_page.dart` → `class StepPage`). We'd rather navigate many small files than
scroll up and down one big one, so do **not** pile a screen's sub-widgets into the screen
file as `_`-private classes.

A screen with its own sub-widgets gets a **folder**:

```
screens/cooking_mode/
  cooking_mode_screen.dart      # CookingModeScreen — the entry point
  cooking_top_bar.dart          # CookingTopBar
  cooking_step_page.dart        # CookingStepPage
  cooking_bottom_controls.dart  # CookingBottomControls
  ...
```

Because Dart privacy is library- (file-)scoped, splitting means the sub-widgets are
**public classes**. Two consequences: prefix screen-only widgets to show ownership and
avoid collisions (`CookingStepPage`, not `StepPage` — note the shared `EmptyState` widget
already exists), and only promote one to the shared `widgets/` directory when something
outside the screen actually reuses it.

### 2. Extract widget *classes*, never `Widget _buildX()` helper methods

A method that returns a widget rebuilds with its parent, can't be `const`, and gets no
element identity. Pull the piece into a widget class (in its own file, per rule 1):

```dart
// ❌ don't — UI assembled from a method
Widget _buildHeader(BuildContext context) { ... }

// ✅ do — a widget class with explicit inputs, in header.dart
class Header extends StatelessWidget {
  final String title;
  const Header({super.key, required this.title});
  @override
  Widget build(BuildContext context) { ... }
}
```

(Non-widget helpers — returning an `InputDecoration`, a `TextStyle`, a formatted string —
are fine as methods/functions; this rule is specifically about helpers that return
`Widget`s. Shared decoration/style helpers belong in `styles/`.)

### 3. Screens orchestrate; sections render

A screen wires providers to a column of section widgets and handles navigation/snackbars
— it does not build form fields or list rows itself. `build` should read like a table of
contents. See `edit_recipe_screen.dart` and `recipe_list_screen.dart`.

### 4. Logic goes in the notifier, not the widget

Validation, save, CRUD, reordering, optimistic toggles — all live in a `StateNotifier`
(`EditRecipeNotifier`, `RecipeListNotifier`). Widgets call `notifier.doThing()` and render
state. If a widget is computing or mutating domain data, move it down.

### 5. Dialogs and bottom sheets are widgets too

Don't inline an `AlertDialog` + `StatefulBuilder` inside a screen's `State`. Make it a
widget in its own file (see `theme_selector_dialog.dart` / `add_label_dialog.dart`) and
`showDialog(builder: (_) => const MyDialog())`.

### Reusable cross-cutting logic lives in `utils/`

Pure helpers (string highlighting, time formatting, the camera/gesture controller) go in
`application/utils/`, not in the widget that happens to use them first
(`ingredient_highlighter.dart`, `time_format.dart`, `wave_gesture_detector.dart`).

### The smell

It's a **single `build` (or `_buildX`) method longer than a screenful**, or a file with
more than one widget class in it. When you hit either, split into classes and files.

### Enforced in CI

Rules 1 and 2 are mechanically checked by `app/tool/widget_lint` (run on every
PR): **one widget class per file**, and **no `Widget`-returning helpers** (only
the framework `build` override may return a `Widget`). A second widget class in a
file — public sibling or private `_SubWidget` — fails the build, as does a
`Widget _buildX()` helper. Non-widget helpers (returning `InputDecoration`, a
`String`, `List<Widget>`, …) are fine.

The backlog has been cleared, so `tool/widget_lint/baseline.txt` is empty and the
check is effectively strict — any new violation fails the build. (The baseline is
a ratchet for grandfathering, if ever needed again: add a signature to keep a
deliberate exception, but don't grow it casually.) Run it locally with
`cd app/tool/widget_lint && dart pub get && dart run widget_lint`. See
`tool/widget_lint/README.md`.

## One concept per file, and keep files small

A single-responsibility rule borrowed from PSR-1/PSR-4: **a file holds one concept,
named after it.** What "one concept" means is layer-specific, and the codebase is
consistent about it:

- **`widgets/`, `screens/` — one widget _class_ per file** (strict; `widget_lint`
  fails the build otherwise). See "Keeping widgets small" above.
- **`domain/` — an aggregate plus its value objects.** `ingredient.dart` holds
  `Ingredient` + `IngredientDetail` + `IngredientUnit`; `label.dart` holds `Label` +
  `LabelSummary`. This mirrors the Go backend's `recipe.go` ("aggregate root + value
  objects").
- **`providers/` — a notifier plus its state.** `chat_providers.dart` holds
  `ChatNotifier` + `ChatMessage`; `edit_recipe_provider.dart` holds `EditRecipeNotifier`,
  its `EditRecipeState`, and the editable value objects it owns.
- **`infrastructure/` — a client plus its result/event type.** `recipe_repository.dart`
  holds `RecipeRepository` + `PaginatedRecipes`; `chat_service.dart` holds `ChatService`
  + `ChatEvent`.

So "one class per file" is the *widget* rule; elsewhere the unit is the concept. The
test is **cohesion**: a value object that only exists to describe its aggregate (or the
state a notifier owns) belongs with it; an unrelated class gets its own file. The file
and its primary type share a name, and the directory mirrors the layering
(`domain` / `application` / `infrastructure`) — the PSR-4 instinct, applied to Dart.

**Size is the canary for SRP.** Aim for small files — a couple hundred lines. Once a
Dart file pushes past ~300 lines it's almost always doing too much; treat that as a
prompt to find a seam and split (extract widgets per the rule above, pull pure helpers
into `utils/`, move logic into a notifier). A few files legitimately run longer —
`colours.dart` is design tokens, the big notifiers are cohesive state machines — so this
is a guideline for review and judgement, **not** a CI gate.

## Domain models

`@freezed` immutable classes with `fromJson`/`toJson`. Generated `*.freezed.dart` and
`*.g.dart` are committed but are outputs — after editing a model run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Field names bridge to the backend with `@JsonKey`.** The API and the app don't always
agree on names, and that's deliberate — the app uses its own vocabulary and maps:

```dart
@freezed
class Recipe with _$Recipe {
  const factory Recipe({
    required String uuid,
    @JsonKey(name: 'prepTime') required int preparationTime,
    @JsonKey(name: 'cookTime') required int cookingTime,
    @JsonKey(name: 'mainPhoto') String? imageUrl,
    required bool isInMealPlan,          // matches the JSON key, so no @JsonKey needed
    // ...
  }) = _Recipe;
}
```

Rule of thumb: only add `@JsonKey(name:)` when the Dart name differs from the JSON key.
If you rename a Go struct tag, update the matching `@JsonKey` here.

## Repository pattern

`RecipeRepository` is the **only** place network calls happen. Every method follows the
same shape: log, call, translate `DioException` into a friendly `Exception` via the
shared `_formatDioError` helper.

```dart
Future<Recipe> getRecipe(String uuid) async {
  try {
    dev.log('Fetching recipe $uuid', name: 'RecipeRepository');
    final response = await _apiClient.dio.get('/recipes/$uuid');
    return Recipe.fromJson(response.data);
  } on DioException catch (e, stack) {
    dev.log('Failed to load recipe $uuid: ${e.message}',
        name: 'RecipeRepository', error: e, stackTrace: stack);
    throw Exception(_formatDioError('Failed to load recipe', e));
  }
}
```

`ApiClient` (`network/api_client.dart`) configures the Dio base URL/timeouts and the
interceptor chain — **`AuthInterceptor` first** (so the token is attached before
logging), then the log interceptor. `AuthInterceptor` caches an OAuth2
`client_credentials` token and transparently retries once on a 401. Base URL is
platform-aware in `ApiConfig` (and overridable with `--dart-define=API_URL=...`).

Logging convention everywhere: `dev.log(..., name: '<ClassName>')` — the mirror of the
backend's structured logs.

## Product analytics

Usage events go to **PostHog**, behind a small `Analytics` interface
(`infrastructure/analytics/analytics.dart`) — mirroring the backend's `recipe.Probe`
shape: an interface the app fires against, a `NoopAnalytics` for when nothing's
listening, and the real `PostHogAnalytics` in infrastructure. Reach it through
`analyticsProvider` (`providers/analytics_providers.dart`); it resolves to
`PostHogAnalytics` when a key is configured and `NoopAnalytics` otherwise, so call sites
fire events unconditionally — **no null checks, and tests/keyless builds send nothing.**

```dart
ref.read(analyticsProvider).capture(
  AnalyticsEvent.mealPlanToggled,
  properties: {'added': true, 'recipe_uuid': uuid},
);
ref.read(analyticsProvider).screen(AnalyticsScreen.recipe);
```

Rules of the road:

- **Configured at build time, off by default.** `AnalyticsConfig` reads
  `POSTHOG_API_KEY` (and optional `POSTHOG_HOST`, defaulting to **EU** cloud) from
  `--dart-define`. No key ⇒ disabled. PostHog is initialised once in `main()` via
  `PostHogAnalytics.setup()` before `runApp`.
- **Event names live in `AnalyticsEvent` / screen names in `AnalyticsScreen`** — never
  inline a raw event string at a call site, so the vocabulary stays consistent and
  greppable.
- **Fire from the notifier, not the widget**, wherever a notifier owns the action (meal
  plan toggle, save, archive, chat send) — the analytics equivalent of the backend's
  "fire probe calls from the service". Screen views and screen-local actions (a search
  keystroke, opening a screen) are fired from the screen.
- **Mind privacy.** Send shapes, not contents: a search is recorded as `query_length`,
  not the query text.

## Riverpod: pick the right tier

- **`Provider`** — dependency injection of stateless services:
  `apiClientProvider`, `recipeRepositoryProvider`.
- **`FutureProvider`** — one-shot async reads with no local mutation:
  `ingredientsProvider`, `unitsProvider`, `labelsProvider`, `mealPlanRecipesProvider`.
  Refresh by `ref.invalidate(...)`.
- **`StateNotifier<AsyncValue<T>>`** — stateful flows: pagination, filters, optimistic
  toggles. `RecipeListNotifier` and `RecipeDetailNotifier` are the templates.
- **`StateProvider`** — trivial UI state (e.g. `searchQueryProvider`).
- **`.family`** — parameterised providers, e.g. `recipeDetailProvider(uuid)`.

State is always wrapped in `AsyncValue`; UI renders it with `.when(data/loading/error)`.

### Optimistic updates with rollback

Mutations update local state immediately, then call the API and **revert on failure**.
Follow this pattern for any toggle/mutation:

```dart
final updated = recipe.copyWith(isInMealPlan: !wasInPlan);
state = AsyncValue.data(/* list with updated */);   // optimistic
try {
  wasInPlan ? await _repo.removeFromMealPlan(uuid) : await _repo.addToMealPlan(uuid);
  _ref.invalidate(mealPlanRecipesProvider);          // refresh dependents
} catch (e, stack) {
  state = AsyncValue.data(/* original */);           // revert
  rethrow;
}
```

`loadMore` is the one place that deliberately swallows errors (keep existing rows
visible rather than blanking the list).

## Styling — theme tokens only

**Never hardcode colours or spacing.** Tokens come from the theme:

- **Colours** via the `Colours` `ThemeExtension`, reached with `context.colours`
  (`context.colours.primary`, `.surfaceContainer`, …). The `ColorScheme` (built by
  `buildAppTheme` in `application/styles/app_theme.dart`) is **hand-built per role** — do
  not switch to `ColorScheme.fromSeed`; tonal values are chosen to match the "Garden
  Plot" design.
- **Spacing** — the `Spacing` constants (`Spacing.m`, `Spacing.horizontal`, …).
- **Text** — `TextStyles.*(context)` (Work Sans body, Instrument Serif for the
  cookbook "serif moments").
- **Shapes** — `Shapes.squircle(...)` etc.

Light/dark are full sibling palettes (`Colours.light` / `Colours.dark`); anything you
add to `Colours` must be filled in for both and threaded through `copyWith`/`lerp`.

## Snapshot (golden) tests

Widget rendering is pinned with [alchemist](https://pub.dev/packages/alchemist) goldens
under `app/test/golden/`. They render a widget to a PNG and diff it against a committed
reference image, catching unintended visual changes (layout, sizing, theme colours).

- **Readable, but still cross-machine deterministic.** `test/flutter_test_config.dart`
  runs alchemist with a single golden set (`test/golden/goldens/ci/`), rendering **real
  text** (`obscureText: false`). Flutter draws goldens through its own engine (Skia + the
  bundled fonts), so given the same Flutter version the PNGs match across machines — your
  dev box and the Ubuntu CI runner agree. Alchemist's separate per-OS "platform" goldens
  are disabled so there's only one set to maintain.
- **Fonts are bundled, not fetched.** The `google_fonts` families are committed as
  `.ttf`s under `app/fonts/` (declared in `pubspec.yaml` `assets:`), so they load offline
  — `flutter test`'s binding blocks all HTTP, which would otherwise make google_fonts
  throw. This also benefits production (no first-launch font flash). Because google_fonts
  loads asynchronously (a font caught mid-load renders as `.notdef` boxes), the test
  config pre-warms every bundled family/variant and awaits `GoogleFonts.pendingFonts()`
  before any test runs — **if you add a new font weight/family, bundle the `.ttf` and add
  a matching warm-up line there**, or goldens for it may render as boxes.
- **Render under the real theme.** Use `themedScenario(...)` from
  `test/golden/golden_support.dart`; it wraps the widget in `buildAppTheme(...)` (the
  shipping theme) for light or dark, so goldens reflect production theming, not a bare
  `ThemeData.light`. Feed widgets deterministic inputs (fixed data, no `DateTime.now()`,
  no network images — pass `imageUrl: null` for the striped placeholder).
- **Workflow.** `flutter test` checks goldens; regenerate after an intended UI change
  with `flutter test --update-goldens` and commit the new PNGs (review the diff!). Run
  just these with `flutter test --tags golden`, or skip them with `flutter test -x golden`.

## Vocabulary

It's **"meal plan"**, never "favourite" — in identifiers, strings, and UI. The star icon
toggles meal-plan membership (`isInMealPlan`); there is no separate favourites feature.

## Adding a screen/feature (checklist)

1. Model the data in `domain/` (freezed); run `build_runner`.
2. Add the API call to `RecipeRepository` (try/catch → `_formatDioError`).
3. Expose it through the right Riverpod tier in `providers/`.
4. Build the UI in `screens/`+`widgets/` using theme tokens; render `AsyncValue` with
   `.when`; use optimistic updates for mutations.
