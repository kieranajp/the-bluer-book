-- name: AddToPantry :exec
-- Resolve the ingredient by its (unique) name and record that we have it.
-- A name that doesn't match a known ingredient inserts nothing.
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

-- name: ListMealPlanShortfall :many
-- Ingredients needed across the (non-archived) meal plan that are NOT already
-- in the pantry. This is the shopping list.
SELECT DISTINCT i.name
FROM meal_plan_recipes mp
INNER JOIN recipes r ON r.uuid = mp.recipe_id AND r.archived_at IS NULL
INNER JOIN recipe_ingredient ri ON ri.recipe_id = mp.recipe_id
INNER JOIN ingredients i ON i.uuid = ri.ingredient_id
LEFT JOIN pantry_items pi ON pi.ingredient_id = ri.ingredient_id
WHERE pi.ingredient_id IS NULL
ORDER BY i.name ASC;
