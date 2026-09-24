-- +goose Up
-- Compensating fix for the semantic merges applied to the live database by
-- hand on 2026-09-22 (before review), whose mapping since changed. Nothing
-- here re-runs those merges: every step resolves names to rows first and
-- degrades to a no-op where they don't exist, so this is safe on a database
-- that never saw the hand-applied mapping.
--
-- Units are NOT pluralisation logic. The book stores units singular (clove)
-- and the app renders 1 clove / 2 cloves; this migration only undoes writes
-- the old mapping got wrong, which happened to include putting a plural into
-- preparation.

-- ---------------------------------------------------------------------------
-- 1. Tomatoes. The old mapping merged "chopped tomatoes" and "tinned
-- tomatoes" into "tinned chopped tomatoes". The reviewed decision: the
-- canonical is "tinned tomatoes", and "chopped" is what the recipe does to
-- them — a preparation, not part of the name. Any recipe line pointing at
-- "tinned chopped tomatoes" ends up pointing at "tinned tomatoes" with
-- preparation "chopped" unless it already says something more specific.
-- ---------------------------------------------------------------------------

-- Per home: every home holding the merged name but no "tinned tomatoes" gets
-- one, so the remap below has a target. Then everything points at it.
CREATE TEMP TABLE tomato_fix (
  home_id     UUID NOT NULL,
  merged_uuid UUID NOT NULL,
  target_uuid UUID
) ON COMMIT DROP;

INSERT INTO tomato_fix (home_id, merged_uuid, target_uuid)
SELECT merged.home_id, merged.uuid,
       (SELECT t.uuid FROM ingredients t
        WHERE t.home_id = merged.home_id
          AND t.canonical_name = 'tinned tomatoes'
        LIMIT 1)
FROM ingredients merged
WHERE merged.canonical_name = 'tinned chopped tomatoes';

INSERT INTO ingredients (uuid, name, canonical_name, created_at, updated_at)
SELECT uuid_generate_v4(), 'tinned tomatoes', 'tinned tomatoes', now(), now()
FROM (
  SELECT DISTINCT home_id FROM tomato_fix WHERE target_uuid IS NULL
) h
ON CONFLICT DO NOTHING;

UPDATE tomato_fix f
SET target_uuid = t.uuid
FROM ingredients t
WHERE f.target_uuid IS NULL
  AND t.home_id = f.home_id
  AND t.canonical_name = 'tinned tomatoes';

UPDATE tomato_fix f
SET target_uuid = t.uuid
FROM ingredients t
WHERE f.target_uuid IS NULL
  AND t.home_id = f.home_id
  AND t.canonical_name = 'tinned tomatoes';

-- Dedupe-before-remap, same as 00019: recipe lines that would collide on
-- (home, recipe, ingredient, component) once ids move.
DELETE FROM recipe_ingredient ri
USING (
  SELECT ri2.home_id, ri2.recipe_id, ri2.ingredient_id, ri2.component,
         row_number() OVER (
           PARTITION BY ri2.home_id, ri2.recipe_id, f.target_uuid, ri2.component
           ORDER BY ri2.created_at ASC, ri2.ingredient_id ASC
         ) AS rn
  FROM recipe_ingredient ri2
  JOIN tomato_fix f ON f.merged_uuid = ri2.ingredient_id
) d
WHERE ri.home_id = d.home_id
  AND ri.recipe_id = d.recipe_id
  AND ri.ingredient_id = d.ingredient_id
  AND ri.component = d.component
  AND d.rn > 1;

UPDATE recipe_ingredient ri
SET ingredient_id = f.target_uuid,
    -- "chopped" is how the recipe uses them, unless the recipe already said.
    preparation = CASE WHEN COALESCE(btrim(ri.preparation), '') = ''
                       THEN 'chopped' ELSE ri.preparation END
FROM tomato_fix f
WHERE ri.ingredient_id = f.merged_uuid;

-- The old alias "chopped tomatoes" → tinned chopped tomatoes pointed recipes
-- saying "chopped tomatoes" at the wrong item. It should retire into the
-- canonical the remap has established.
DELETE FROM ingredient_aliases WHERE alias = 'chopped tomatoes';
INSERT INTO ingredient_aliases (alias, ingredient_id)
SELECT 'chopped tomatoes', f.target_uuid
FROM tomato_fix f
WHERE f.target_uuid IS NOT NULL
ON CONFLICT (alias) DO NOTHING;

DELETE FROM ingredient_aliases WHERE alias = 'tinned tomatoes';

DELETE FROM ingredients i
USING tomato_fix f
WHERE i.uuid = f.merged_uuid
  AND f.target_uuid IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Garlic. The old mapping wrote preparation 'cloves' onto lines merged
-- from "garlic cloves". Under the corrected model that qualifier is the
-- unit, not a preparation: unit is the singular "clove", preparation empty.
-- Only lines that still carry preparation 'cloves' are touched — a recipe
-- that said something more specific is left alone.
-- ---------------------------------------------------------------------------

-- Resolve the unit once; it is global (00008), so no home scoping here.
INSERT INTO units (uuid, name, abbreviation, created_at, updated_at)
SELECT uuid_generate_v4(), 'clove', '', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM units WHERE name = 'clove');

UPDATE recipe_ingredient ri
SET preparation = '',
    unit_id = (SELECT uuid FROM units WHERE name = 'clove')
WHERE btrim(ri.preparation) = 'cloves'
  AND EXISTS (
    SELECT 1 FROM ingredients i
    WHERE i.uuid = ri.ingredient_id
      AND i.canonical_name = 'garlic'
  );

-- ---------------------------------------------------------------------------
-- 3. Cilantro. UK usage: coriander. The alias should point at whichever
-- coriander row the home has; if the book holds no coriander at all, the
-- alias is simply deleted. No ingredient row named cilantro is created.
-- ---------------------------------------------------------------------------
DELETE FROM ingredient_aliases WHERE alias = 'cilantro';
INSERT INTO ingredient_aliases (alias, ingredient_id)
SELECT 'cilantro', i.uuid
FROM ingredients i
WHERE i.canonical_name = 'coriander'
ON CONFLICT (alias) DO NOTHING;

DELETE FROM ingredient_aliases WHERE alias = 'fresh cilantro';