-- All queries below run inside repository.InHomeTx, which sets the
-- app.home_id GUC via SET LOCAL. Pulling home_id from
-- current_setting('app.home_id', true)::uuid keeps the Go call signatures
-- unchanged and means RLS + the explicit predicate agree on the rows.

-- name: AddToPantry :exec
-- Resolve the ingredient by name *within the caller's home* and record that
-- the home has it. A name that doesn't match a known ingredient in this
-- home inserts nothing.
INSERT INTO pantry_items (ingredient_id, home_id)
SELECT uuid, current_setting('app.home_id', true)::uuid
FROM ingredients
WHERE name = $1
  AND home_id = current_setting('app.home_id', true)::uuid
ON CONFLICT (home_id, ingredient_id) DO NOTHING;

-- name: RemoveFromPantry :exec
DELETE FROM pantry_items
WHERE home_id = current_setting('app.home_id', true)::uuid
  AND ingredient_id = (
    SELECT uuid FROM ingredients
    WHERE name = $1
      AND home_id = current_setting('app.home_id', true)::uuid
  );

-- name: ListPantry :many
SELECT i.name, p.added_at
FROM pantry_items p
INNER JOIN ingredients i ON i.uuid = p.ingredient_id
WHERE p.home_id = current_setting('app.home_id', true)::uuid
  AND i.home_id = current_setting('app.home_id', true)::uuid
ORDER BY i.name ASC;

-- name: AddCustomShoppingItem :exec
-- Add a free-text item to the home's shopping list (e.g. "washing-up
-- liquid"). Deduped case-insensitively per-home so repeat adds — manual
-- or from a scan — are no-ops.
INSERT INTO shopping_list_items (name, home_id)
SELECT @name::varchar, current_setting('app.home_id', true)::uuid
WHERE NOT EXISTS (
  SELECT 1 FROM shopping_list_items
  WHERE home_id = current_setting('app.home_id', true)::uuid
    AND lower(name) = lower(@name::varchar)
);

-- name: RemoveCustomShoppingItem :exec
DELETE FROM shopping_list_items
WHERE home_id = current_setting('app.home_id', true)::uuid
  AND lower(name) = lower(@name::varchar);

-- name: ListCustomShoppingItems :many
SELECT name FROM shopping_list_items
WHERE home_id = current_setting('app.home_id', true)::uuid
ORDER BY name ASC;

-- name: ListMealPlanShortfall :many
-- Ingredients needed across the (non-archived) meal plan that are NOT
-- already in the home's pantry. Every join here is gated by the home id;
-- without a home in context the query returns zero rows (fail-closed).
SELECT DISTINCT i.name
FROM meal_plan_recipes mp
INNER JOIN recipes r
  ON r.uuid = mp.recipe_id
 AND r.archived_at IS NULL
 AND r.home_id = current_setting('app.home_id', true)::uuid
INNER JOIN recipe_ingredient ri
  ON ri.recipe_id = mp.recipe_id
 AND ri.home_id = current_setting('app.home_id', true)::uuid
INNER JOIN ingredients i
  ON i.uuid = ri.ingredient_id
 AND i.home_id = current_setting('app.home_id', true)::uuid
LEFT JOIN pantry_items pi
  ON pi.ingredient_id = ri.ingredient_id
 AND pi.home_id = current_setting('app.home_id', true)::uuid
WHERE mp.home_id = current_setting('app.home_id', true)::uuid
  AND pi.ingredient_id IS NULL
ORDER BY i.name ASC;
