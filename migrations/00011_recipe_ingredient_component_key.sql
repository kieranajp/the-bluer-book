-- +goose Up
-- Let one recipe use the same ingredient in more than one component.
--
-- The primary key was (recipe_id, ingredient_id), which cannot represent "salt
-- in the sauce and salt in the batter" — a shape 00006 added `component`
-- precisely to support. The repository has been papering over the gap with an
-- in-memory `ingredientSet` guard that silently discards the second row along
-- with its own quantity and preparation.
--
-- Widening the key retires that guard, and is a prerequisite for canonicalising
-- ingredient names: once "Salt" and "salt" collapse onto one ingredient row,
-- any recipe listing both would collide on the old key.

-- component joins the key, so it can no longer be NULL. '' is the "no
-- component" case and is what the Go layer already writes for an empty string.
UPDATE recipe_ingredient SET component = '' WHERE component IS NULL;
ALTER TABLE recipe_ingredient ALTER COLUMN component SET DEFAULT '';
ALTER TABLE recipe_ingredient ALTER COLUMN component SET NOT NULL;

ALTER TABLE recipe_ingredient DROP CONSTRAINT recipe_ingredient_pkey;
ALTER TABLE recipe_ingredient ADD PRIMARY KEY (recipe_id, ingredient_id, component);

-- +goose Down
-- Narrowing the key needs one row per (recipe, ingredient) again; keep the
-- alphabetically-first component and drop the rest. Lossy by nature — the
-- discarded rows carried their own quantities.
ALTER TABLE recipe_ingredient DROP CONSTRAINT recipe_ingredient_pkey;

DELETE FROM recipe_ingredient ri
USING (
  SELECT recipe_id, ingredient_id, min(component) AS keep
  FROM recipe_ingredient
  GROUP BY recipe_id, ingredient_id
) k
WHERE ri.recipe_id = k.recipe_id
  AND ri.ingredient_id = k.ingredient_id
  AND ri.component <> k.keep;

ALTER TABLE recipe_ingredient ADD PRIMARY KEY (recipe_id, ingredient_id);
ALTER TABLE recipe_ingredient ALTER COLUMN component DROP NOT NULL;
ALTER TABLE recipe_ingredient ALTER COLUMN component DROP DEFAULT;
