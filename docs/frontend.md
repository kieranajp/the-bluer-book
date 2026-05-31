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
The codebase stays readable by following four rules — when you touch the UI, keep to
them.

### 1. Extract widget *classes*, never `Widget _buildX()` helper methods

A method that returns a widget rebuilds with its parent, can't be `const`, gets no
element identity, and quietly turns into the 1000-line file we're avoiding. Pull the
piece out into a private `StatelessWidget`/`StatefulWidget` class with named fields
instead.

```dart
// ❌ don't — UI assembled from a method on the State/widget
Widget _buildHeader(BuildContext context) { ... }

// ✅ do — a real widget class with explicit inputs
class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});
  @override
  Widget build(BuildContext context) { ... }
}
```

`edit_recipe_screen.dart`'s `_FormTextField` and all of `cooking_mode_screen.dart`'s
`_TopBar` / `_StepPage` / `_BottomControls` are the model to copy. (A handful of older
`_buildX` methods survive in `ingredient_edit_card.dart`, `instructions_list.dart` and
`meal_plan_carousel.dart` — treat those as debt to migrate, not as a pattern to follow.)

### 2. Screens orchestrate; sections render

A screen widget wires providers to a column of section widgets and handles
navigation/snackbars — it does not build form fields or list rows itself. `build` should
read like a table of contents. See `edit_recipe_screen.dart` (delegates to
`_BasicInfoSection`, `_IngredientsSection`, …) and `recipe_list_screen.dart`.

### 3. Logic goes in the notifier, not the widget

Validation, save, CRUD, reordering, optimistic toggles — all live in a `StateNotifier`
(`EditRecipeNotifier`, `RecipeListNotifier`). Widgets call `notifier.doThing()` and
render state. If a widget is computing or mutating domain data, move it down.

### 4. Dialogs and bottom sheets are widgets too

Don't inline an `AlertDialog` + `StatefulBuilder` inside a screen's `State`. Make it a
widget (see `theme_selector_dialog.dart`) and `showDialog(builder: (_) => MyDialog())`.
(`edit_recipe_screen.dart`'s `_addLabel` is the current exception to fix.)

### Reusable cross-cutting logic lives in `utils/`

Pure helpers (string highlighting, time formatting, the camera/gesture controller) go in
`application/utils/`, not in the widget that happens to use them first
(`ingredient_highlighter.dart`, `time_format.dart`, `wave_gesture_detector.dart`).

### Rule of thumb on size

There's no hard line limit — `cooking_mode_screen.dart` is 700 lines and perfectly fine
because it's ~10 small widget classes. The smell isn't file length, it's a **single
`build` method** (or `_buildX` helper) that's longer than a screenful. When one is, split
it into classes.

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
  (`context.colours.primary`, `.surfaceContainer`, …). The `ColorScheme` in `main.dart`
  is **hand-built per role** — do not switch to `ColorScheme.fromSeed`; tonal values are
  chosen to match the "Garden Plot" design.
- **Spacing** — the `Spacing` constants (`Spacing.m`, `Spacing.horizontal`, …).
- **Text** — `TextStyles.*(context)` (Work Sans body, Instrument Serif for the
  cookbook "serif moments").
- **Shapes** — `Shapes.squircle(...)` etc.

Light/dark are full sibling palettes (`Colours.light` / `Colours.dark`); anything you
add to `Colours` must be filled in for both and threaded through `copyWith`/`lerp`.

## Vocabulary

It's **"meal plan"**, never "favourite" — in identifiers, strings, and UI. The star icon
toggles meal-plan membership (`isInMealPlan`); there is no separate favourites feature.

## Adding a screen/feature (checklist)

1. Model the data in `domain/` (freezed); run `build_runner`.
2. Add the API call to `RecipeRepository` (try/catch → `_formatDioError`).
3. Expose it through the right Riverpod tier in `providers/`.
4. Build the UI in `screens/`+`widgets/` using theme tokens; render `AsyncValue` with
   `.when`; use optimistic updates for mutations.
