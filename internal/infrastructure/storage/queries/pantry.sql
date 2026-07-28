-- name: FindIngredientByName :one
-- Resolve a free-text ingredient name to a known ingredient. Matching is
-- trimmed and case-insensitive: MCP callers and the chat agent type names by
-- hand ("Olive Oil") and rarely match the casing a recipe happened to store
-- ("olive oil"). Ingredient names are only unique verbatim, so the same thing
-- can exist under several casings; an exact-casing match wins, then the oldest
-- row, so resolution is deterministic and collation-independent.
SELECT uuid, name FROM ingredients
WHERE lower(name) = lower(btrim(@name::varchar))
ORDER BY (name = btrim(@name::varchar)) DESC, created_at ASC, uuid ASC
LIMIT 1;

-- name: AddToPantry :exec
-- Takes an ingredient UUID, not a name: the caller resolves the name first via
-- FindIngredientByName so an unknown ingredient is a reported error rather than
-- an INSERT ... SELECT that quietly matches nothing.
INSERT INTO pantry_items (ingredient_id)
VALUES (@ingredient_id)
ON CONFLICT (ingredient_id) DO NOTHING;

-- name: RemoveFromPantry :exec
-- Clears every casing variant, so a pantry that predates case-insensitive
-- resolution ("Salt" and "salt" as separate rows) empties in one go.
DELETE FROM pantry_items
WHERE ingredient_id IN (
  SELECT uuid FROM ingredients WHERE lower(name) = lower(btrim(@name::varchar))
);

-- name: ListPantry :many
-- Casing variants of one ingredient collapse to a single line. The pantry is
-- presence-only, so listing "Salt" and "salt" separately would just read as a
-- bug.
SELECT DISTINCT ON (lower(i.name)) i.name, p.added_at
FROM pantry_items p
INNER JOIN ingredients i ON i.uuid = p.ingredient_id
ORDER BY lower(i.name) ASC, p.added_at ASC;

-- name: AddCustomShoppingItem :exec
-- Add a free-text item to the shopping list (e.g. "washing-up liquid"). These
-- aren't recipe ingredients, so they live in their own table. Deduped
-- case-insensitively so repeat adds — manual or from a scan — are no-ops.
INSERT INTO shopping_list_items (name)
SELECT @name::varchar
WHERE NOT EXISTS (
  SELECT 1 FROM shopping_list_items WHERE lower(name) = lower(@name::varchar)
);

-- name: RemoveCustomShoppingItem :exec
DELETE FROM shopping_list_items WHERE lower(name) = lower(@name::varchar);

-- name: ListCustomShoppingItems :many
SELECT name FROM shopping_list_items ORDER BY name ASC;

-- name: ListMealPlanShortfall :many
-- Ingredients needed across the (non-archived) meal plan that are NOT already
-- in the pantry. This is the shopping list. Pantry coverage is matched on the
-- ingredient name case-insensitively rather than on ingredient_id, so a pantry
-- stocked with "Salt" still covers a recipe that calls for "salt".
SELECT DISTINCT i.name
FROM meal_plan_recipes mp
INNER JOIN recipes r ON r.uuid = mp.recipe_id AND r.archived_at IS NULL
INNER JOIN recipe_ingredient ri ON ri.recipe_id = mp.recipe_id
INNER JOIN ingredients i ON i.uuid = ri.ingredient_id
WHERE NOT EXISTS (
  SELECT 1
  FROM pantry_items pi
  INNER JOIN ingredients pi_i ON pi_i.uuid = pi.ingredient_id
  WHERE lower(pi_i.name) = lower(i.name)
)
ORDER BY i.name ASC;
