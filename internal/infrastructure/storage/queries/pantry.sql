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
