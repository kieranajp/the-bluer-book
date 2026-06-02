# Design: Pantry inventory → "what can I cook" + shopping list

> Status: **Phases 1–3 implemented** (pantry CRUD + checkoff; "what can I cook"
> badges/sort; shopping list from the meal plan). Only "Future: quantities & units"
> remains. Scope decisions baked in (agreed up front):
> - **Matching: have / don't-have only.** Track _presence_ of an ingredient, not
>   quantities or units. Avoids the unit-conversion problem entirely for v1.
> - **Single-user / shared.** One pantry, one meal plan, like the existing
>   `meal_plan_recipes` table (no `user_id`).
> - **Build order:** design first; implementation phased (see Roadmap).
>
> **Implementation note — keyed by ingredient name, not UUID.** Ingredient UUIDs
> are never exposed to the client (the Go `Ingredient` value object and the
> Flutter `IngredientDetail` model carry only `name`, which is `UNIQUE` in the
> `ingredients` table). The pantry API therefore speaks ingredient _names_ and
> resolves them to the `ingredient_id` FK server-side — simpler and consistent
> with the rest of the app. The table still stores the FK, so the matching
> joins in Phases 2–3 are unchanged.

## The idea

A **pantry** is the list of ingredients you currently have at home. Because recipes
already reference ingredients by UUID (`recipe_ingredient.ingredient_id → ingredients.uuid`),
the pantry is just *another set of ingredient UUIDs* — and the three features the user
wants all fall out as **joins over data that already exists**:

| Feature | How it's computed |
| --- | --- |
| **What can I cook** | For each recipe, how many of its ingredients are in the pantry? `total − have = missing`. Rank by fewest missing. |
| **What am I missing for my meal plan** | Union of ingredients across `meal_plan_recipes`, minus the pantry. |
| **Shopping list** | That gap, deduplicated. Checking an item off → it enters the pantry. |

The big win: the existing `ingredients` table is already normalised (unique names, shared
UUIDs across recipes), so "do I have this?" is an equality join — **no fuzzy text matching,
no NLP.** This is the hard part of most inventory apps, and the schema already solved it.

## Where the existing "ingredient checkoff" fits

This design answers the original question — *"checking ingredients off doesn't seem to do
anything"* (`app/lib/application/widgets/ingredients_list.dart`, in-memory `Set<int>` only).
It gets a real meaning:

> **Tapping an ingredient in a recipe = "I have this in my pantry."**

The checkbox toggle calls the pantry add/remove API instead of mutating throwaway local
state. Checked rows reflect "in pantry" and persist. Same widget, same gesture — now backed
by real data. (Optional later: a per-cooking-session "used it up" mode that *removes* from
the pantry; out of scope for v1.)

---

## Backend

Follows the layering in `docs/backend.md`: `queries/*.sql` (sqlc) → `repository` →
`domain` service → REST handler + route. Mirrors the meal-plan feature, which is the
closest existing analog.

### 1. Schema — `migrations/00009_pantry.sql`

Deliberately mirrors `meal_plan_recipes`: single-column PK, no `user_id`, an `added_at`
for ordering. Presence-only.

```sql
-- A pantry item is simply "I have this ingredient at home".
-- Presence-only by design (v1): no quantity/unit (see "Future: quantities").
CREATE TABLE pantry_items (
  ingredient_id UUID PRIMARY KEY REFERENCES ingredients(uuid) ON DELETE CASCADE,
  added_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_pantry_items_added_at ON pantry_items(added_at DESC);
```

### 2. Queries — `internal/infrastructure/storage/queries/pantry.sql`

```sql
-- name: AddToPantry :exec
-- Resolve the ingredient by its (unique) name and record that we have it.
INSERT INTO pantry_items (ingredient_id)
SELECT uuid FROM ingredients WHERE name = $1
ON CONFLICT (ingredient_id) DO NOTHING;

-- name: RemoveFromPantry :exec
DELETE FROM pantry_items
WHERE ingredient_id = (SELECT uuid FROM ingredients WHERE name = $1);

-- name: ListPantry :many
SELECT i.name, p.added_at
FROM pantry_items p
INNER JOIN ingredients i ON i.uuid = p.ingredient_id
ORDER BY i.name ASC;

-- name: ListCookableRecipes :many
-- Every non-archived recipe, annotated with how many of its ingredients
-- are already in the pantry. missing = total - have. Sort by least missing.
SELECT
  r.uuid, r.name, r.description, r.cook_time, r.prep_time, r.servings,
  ph.uuid AS main_photo_uuid, ph.url AS main_photo_url, r.url,
  r.created_at, r.updated_at, r.archived_at,
  COUNT(ri.ingredient_id)                  AS total_ingredients,
  COUNT(pi.ingredient_id)                  AS have_ingredients
FROM recipes r
INNER JOIN recipe_ingredient ri ON ri.recipe_id = r.uuid
LEFT  JOIN pantry_items pi      ON pi.ingredient_id = ri.ingredient_id
LEFT  JOIN photos ph            ON r.main_photo_id = ph.uuid
WHERE r.archived_at IS NULL
GROUP BY r.uuid, ph.uuid, ph.url
ORDER BY (COUNT(ri.ingredient_id) - COUNT(pi.ingredient_id)) ASC, r.name ASC;

-- name: ListMealPlanShortfall :many
-- Ingredients needed across the whole meal plan that are NOT in the pantry.
-- This IS the shopping list (Phase 3).
SELECT DISTINCT i.uuid, i.name
FROM meal_plan_recipes mp
INNER JOIN recipe_ingredient ri ON ri.recipe_id = mp.recipe_id
INNER JOIN ingredients i        ON i.uuid = ri.ingredient_id
LEFT  JOIN pantry_items pi       ON pi.ingredient_id = ri.ingredient_id
WHERE pi.ingredient_id IS NULL
ORDER BY i.name ASC;
```

Run `sqlc generate` after adding these (the `db/` package is git-ignored and regenerated).

### 3. Domain — `internal/domain/pantry/`

A small new aggregate (keeps pantry concerns out of the recipe domain). Same
interface + unexported impl + `NewX` shape as `RecipeService`.

```go
// domain/pantry/pantry.go
type PantryItem struct {
    Ingredient recipe.Ingredient // reuse the existing value object
    AddedAt    time.Time
}

// A recipe annotated with pantry coverage, for "what can I cook".
type CookableRecipe struct {
    Recipe   recipe.Recipe
    Total    int // ingredients the recipe needs
    Have     int // of those, how many are in the pantry
    // Missing() int => Total - Have
}
```

```go
// domain/pantry/service/pantry_service.go
type PantryService interface {
    Add(ctx context.Context, ingredientID uuid.UUID) error
    Remove(ctx context.Context, ingredientID uuid.UUID) error
    List(ctx context.Context) ([]pantry.PantryItem, error)
    Cookable(ctx context.Context) ([]pantry.CookableRecipe, error) // Phase 2
    Shortfall(ctx context.Context) ([]recipe.Ingredient, error)    // Phase 3 (shopping list)
}
```

- Add a `pantry.Probe` interface (`PantryChanged`, `PantryError`) with a Prometheus impl
  and a `NoopPantryProbe`, per the Probe pattern. Fire probe calls from the service.
- Typed errors + sentinels (`ErrIngredientNotFound`) following the `errors.Is` convention.

### 4. Repository — `internal/infrastructure/storage/repository/pantry.go`

The only place importing `db`. Maps sqlc rows ↔ domain types via `storage/mapper`. No
transactions needed for single-row add/remove; `Cookable`/`Shortfall` are read-only.

### 5. REST — handler + routes in `internal/application/api/`

New `PantryHandler` (concrete struct, like `RecipeHandler`). Reuses `recipeIDFromPath`-style
UUID validation for the ingredient id, and the standard error envelope.

```
GET    /api/pantry                      → { "items": [...], "total": N }   # ListPantry
PUT    /api/pantry/{ingredient}         → 204                              # AddToPantry
DELETE /api/pantry/{ingredient}         → 204                              # RemoveFromPantry
GET    /api/recipes/cookable            → { "recipes": [...] }             # Phase 2
GET    /api/shopping-list               → { "items": [...] }               # Phase 3
```

`{ingredient}` is the URL-encoded ingredient name. `PUT` (idempotent add) pairs
with the `ON CONFLICT DO NOTHING` upsert — repeat taps are safe.

### 6. MCP (optional, nice-to-have)

The chat agent picks up new MCP tools automatically (`docs/backend.md`). Adding
`add_to_pantry` / `list_pantry` / `what_can_i_cook` tools means the user can say
*"add eggs and milk to my pantry"* or *"what can I make tonight?"* in chat. Low cost
once the service exists; can come after the REST/UI core.

---

## Frontend (Flutter / Riverpod)

Mirrors recipe data flow: `domain/*.dart` (freezed) → `infrastructure/*_repository.dart`
(Dio) → `application/providers/*.dart` (Riverpod) → screens/widgets.

### New / changed pieces

1. **`domain/pantry_item.dart`** — freezed model (`Ingredient` + `addedAt`).
2. **`infrastructure/pantry_repository.dart`** — Dio calls to the endpoints above.
3. **`application/providers/pantry_providers.dart`** —
   - `pantryProvider` (the set of ingredient UUIDs you have),
   - `cookableRecipesProvider`, `shoppingListProvider`.
4. **`application/screens/pantry_screen.dart`** + a tab in `app_shell.dart`
   (alongside Recipes / Meal plan / Chat). List your ingredients; add via the existing
   ingredient autocomplete (`unit_autocomplete_field.dart` is a pattern to copy);
   swipe-to-remove (`swipe_to_reveal.dart` already exists).
5. **Wire up `ingredients_list.dart`** (the original ask): replace the in-memory
   `Set<int> _checked` with the pantry. A checked row = ingredient is in your pantry;
   tapping calls `pantryRepository.add/remove` and invalidates `pantryProvider`. The
   "X of Y ready" summary becomes "X of Y in your pantry" — and it's now *true*.

### "What can I cook" surfacing — **implemented (Phase 2), frontend-only**

The recipe list already ships each recipe's full ingredient list, and Phase 1 already
exposes the pantry as a `Set<String>` of names. So cookability is computed entirely on
the client — **no `ListCookableRecipes` query, no `/api/recipes/cookable` endpoint, no
migration** (a deliberate simplification of the original sketch below):

- `application/utils/cookability.dart` — `cookabilityOf(recipe, pantry)` → `{total, have,
  missing, ready}`.
- `recipe_row.dart` — a small badge per card: **"Ready"** (have all) or **"Missing N"**,
  shown only once the pantry is non-empty.
- `RecipeSort.cookable` ("Cook now") — re-sorts the loaded recipes by fewest missing
  (ready first). Since the list is server-paginated and there's no server-side cookable
  sort, this orders what's currently loaded — approximate across pages until more load.
  Accepted trade-off (chosen over a dedicated view).

---

## Roadmap (phased)

**Phase 1 — Pantry CRUD + wire the checkoff** _(foundation; delivers immediate value)_
- Migration, queries, repo, `PantryService` (Add/Remove/List), REST endpoints.
- Pantry screen + tab.
- Re-point `ingredients_list.dart` at the pantry → the checkoff finally persists.

**Phase 2 — "What can I cook"** ✅ _shipped (frontend-only; see above)_
- ~~`ListCookableRecipes` query + `Cookable()` service method + `/api/recipes/cookable`~~
  — turned out unnecessary: the client already has each recipe's ingredients + the pantry,
  so cookability is computed client-side.
- Recipe-list badges + "Cook now" sort.

**Phase 3 — Shopping list from the meal plan** ✅ _shipped_
- `ListMealPlanShortfall` query (DISTINCT ingredient names across non-archived meal-plan
  recipes, minus the pantry) + `PantryService.ShoppingList` + `GET /api/shopping-list`
  → `{ "items": [name, …], "total": N }`.
- Shopping-list screen, opened from a cart action on the Meal Plan screen. Checking an
  item off reuses `PUT /api/pantry/{ingredient}` — it lands in the pantry and drops off
  the list (optimistic; invalidates `pantryProvider`). Closes the loop.

**Future — quantities & units (explicitly out of v1)**
- The natural extension point is adding `quantity DOUBLE PRECISION` + `unit_id UUID` to
  `pantry_items`. Then "have/don't-have" becomes "have *enough*", and the shopping list can
  compute *how much* to buy. This is where unit reconciliation (g↔kg, "1 onion"↔grams)
  becomes necessary — deferred deliberately so v1 can ship.

---

## Open questions for review

1. **Pantry tab placement** — new top-level tab, or a section inside an existing screen?
2. **Cookability threshold** — surface only fully-cookable recipes, or also "missing 1–2"
   (with the missing ones listed)? Affects how aggressive the "what can I cook" view is.
3. **Staples** — things like salt/oil/water clutter "missing" lists. Worth a
   "pantry staple" flag later so they're assumed-present? (Future, but flags a schema hook.)
4. **MCP tools** — include the chat-agent tools in Phase 1, or defer to after the UI lands?
