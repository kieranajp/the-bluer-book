-- name: FindIngredientByName :one
-- Resolve a free-text ingredient name to a known ingredient. MCP callers and
-- the chat agent type names by hand ("Olive Oil", "cilantro") and rarely match
-- what a recipe happened to store, so matching goes through two layers:
-- canonical_name first, then the alias table (retired spellings and synonyms).
-- Both are unique keys, so this yields at most one row per layer and the
-- priority column makes canonical win deterministically.
SELECT uuid, name, canonical_name, is_staple FROM (
  SELECT i.uuid, i.name, i.canonical_name, i.is_staple, 0 AS priority
  FROM ingredients i
  WHERE i.canonical_name = lower(btrim(@name::varchar))
  UNION ALL
  SELECT i.uuid, i.name, i.canonical_name, i.is_staple, 1 AS priority
  FROM ingredient_aliases a
  INNER JOIN ingredients i ON i.uuid = a.ingredient_id
  WHERE a.alias = lower(btrim(@name::varchar))
) matches
ORDER BY priority ASC
LIMIT 1;

-- name: AddToPantry :exec
-- Takes an ingredient UUID, not a name: the caller resolves the name first via
-- FindIngredientByName so an unknown ingredient is a reported error rather than
-- an INSERT ... SELECT that quietly matches nothing.
INSERT INTO pantry_items (ingredient_id)
VALUES (@ingredient_id)
ON CONFLICT (ingredient_id) DO NOTHING;

-- name: RemoveFromPantry :exec
-- Also UUID-keyed. It used to delete every casing variant by name; since 00012
-- gave ingredients a canonical identity there is only ever one row to remove.
DELETE FROM pantry_items WHERE ingredient_id = @ingredient_id;

-- name: ListPantry :many
-- Ordered by canonical_name so the list reads case-insensitively alphabetical
-- while still displaying the name as written.
SELECT i.name, i.canonical_name, p.added_at
FROM pantry_items p
INNER JOIN ingredients i ON i.uuid = p.ingredient_id
ORDER BY i.canonical_name ASC;

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
-- in the pantry. This is the shopping list.
--
-- Back to a plain ingredient_id join: it briefly had to compare lowercased
-- names because "Salt" and "salt" were different rows, which 00012 fixed at the
-- source. Staples are assumed in the cupboard and never listed.
SELECT DISTINCT i.name
FROM meal_plan_recipes mp
INNER JOIN recipes r ON r.uuid = mp.recipe_id AND r.archived_at IS NULL
INNER JOIN recipe_ingredient ri ON ri.recipe_id = mp.recipe_id
INNER JOIN ingredients i ON i.uuid = ri.ingredient_id
LEFT JOIN pantry_items pi ON pi.ingredient_id = ri.ingredient_id
WHERE pi.ingredient_id IS NULL
  AND i.is_staple = false
ORDER BY i.name ASC;

-- name: SetIngredientStaple :exec
-- Staples are the things always in the cupboard — salt, oil, water. Flagging one
-- keeps it off every shopping list and treats it as present for "what can I
-- cook". Keyed by UUID; the caller resolves the name first.
UPDATE ingredients SET is_staple = @is_staple, updated_at = now()
WHERE uuid = @uuid;
