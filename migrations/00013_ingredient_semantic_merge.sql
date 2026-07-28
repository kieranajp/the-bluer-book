-- +goose Up
-- Apply the reviewed semantic ingredient merges, and seed the synonym aliases.
--
-- 00012 merged casing variants, which needs no judgement. What is left needs
-- plenty: "onions" and "onion" are the same shopping item, "garlic cloves" is
-- "garlic" with a qualifier that belongs on the recipe line, and "ground cumin"
-- and "cumin seeds" are emphatically NOT the same thing however similar they
-- look. That call can't be made mechanically, and it can't be made safely by a
-- model unsupervised either.
--
-- So the mapping below is data, reviewed by a human, and this migration is the
-- deterministic machinery that applies it. To produce it:
--
--   go run . propose-ingredient-merges --dry-run     # inspect
--   go run . propose-ingredient-merges               # writes migrations/data/ingredient_merges.json
--
-- then read the JSON, delete anything you disagree with, and transcribe what
-- survives into the INSERT below. The command validates its own output — it
-- drops merges that cross a form boundary, chain, or name an ingredient that
-- doesn't exist — but it proposes; you decide.
--
-- Until the INSERT is filled in the merge section is a no-op, so this migration
-- is safe to apply as it stands. The synonym aliases at the bottom apply either
-- way.
--
-- One-way, like 00008 and 00012: no Down section.

CREATE TEMP TABLE semantic_merge (
  from_name   VARCHAR NOT NULL,
  to_name     VARCHAR NOT NULL,
  preparation VARCHAR NOT NULL DEFAULT ''
) ON COMMIT DROP;

-- ---------------------------------------------------------------------------
-- Reviewed merges go here, canonical names only. Examples of the two shapes:
--
-- INSERT INTO semantic_merge (from_name, to_name, preparation) VALUES
--   ('onions',        'onion',  ''),        -- plural of the same item
--   ('garlic cloves', 'garlic', 'cloves');  -- qualifier moves to the recipe line
-- ---------------------------------------------------------------------------

-- Resolve names to rows, dropping any line whose ingredients no longer exist so
-- a stale mapping degrades to a no-op instead of failing the deploy.
CREATE TEMP TABLE semantic_merge_ids (
  old_uuid    UUID NOT NULL,
  new_uuid    UUID NOT NULL,
  from_name   VARCHAR NOT NULL,
  preparation VARCHAR NOT NULL
) ON COMMIT DROP;

INSERT INTO semantic_merge_ids (old_uuid, new_uuid, from_name, preparation)
SELECT old_i.uuid, new_i.uuid, m.from_name, m.preparation
FROM semantic_merge m
INNER JOIN ingredients old_i ON old_i.canonical_name = lower(btrim(m.from_name))
INNER JOIN ingredients new_i ON new_i.canonical_name = lower(btrim(m.to_name))
WHERE old_i.uuid <> new_i.uuid;

-- A qualifier lifted out of the name has to land somewhere or it is simply
-- lost. Only fill preparation where the recipe hasn't already said something
-- more specific.
UPDATE recipe_ingredient ri
SET preparation = m.preparation
FROM semantic_merge_ids m
WHERE ri.ingredient_id = m.old_uuid
  AND m.preparation <> ''
  AND COALESCE(btrim(ri.preparation), '') = '';

-- Same dedupe-before-remap as 00012: recipe_ingredient keys on
-- (recipe_id, ingredient_id, component) and pantry_items on ingredient_id, so
-- collisions have to be resolved before the ids move.
DELETE FROM recipe_ingredient ri
USING (
  SELECT ri2.recipe_id, ri2.ingredient_id, ri2.component,
         row_number() OVER (
           PARTITION BY ri2.recipe_id,
                        COALESCE(m.new_uuid, ri2.ingredient_id),
                        ri2.component
           ORDER BY (m.new_uuid IS NULL) DESC, ri2.created_at ASC, ri2.ingredient_id ASC
         ) AS rn
  FROM recipe_ingredient ri2
  LEFT JOIN semantic_merge_ids m ON m.old_uuid = ri2.ingredient_id
  WHERE EXISTS (
    SELECT 1 FROM semantic_merge_ids s
    WHERE s.old_uuid = ri2.ingredient_id OR s.new_uuid = ri2.ingredient_id
  )
) d
WHERE ri.recipe_id = d.recipe_id
  AND ri.ingredient_id = d.ingredient_id
  AND ri.component = d.component
  AND d.rn > 1;

UPDATE recipe_ingredient ri
SET ingredient_id = m.new_uuid
FROM semantic_merge_ids m
WHERE ri.ingredient_id = m.old_uuid;

DELETE FROM pantry_items p
USING (
  SELECT p2.ingredient_id,
         row_number() OVER (
           PARTITION BY COALESCE(m.new_uuid, p2.ingredient_id)
           ORDER BY (m.new_uuid IS NULL) DESC, p2.added_at ASC, p2.ingredient_id ASC
         ) AS rn
  FROM pantry_items p2
  LEFT JOIN semantic_merge_ids m ON m.old_uuid = p2.ingredient_id
  WHERE EXISTS (
    SELECT 1 FROM semantic_merge_ids s
    WHERE s.old_uuid = p2.ingredient_id OR s.new_uuid = p2.ingredient_id
  )
) d
WHERE p.ingredient_id = d.ingredient_id AND d.rn > 1;

UPDATE pantry_items p
SET ingredient_id = m.new_uuid
FROM semantic_merge_ids m
WHERE p.ingredient_id = m.old_uuid;

UPDATE photos ph
SET entity_id = m.new_uuid
FROM semantic_merge_ids m
WHERE ph.entity_type = 'ingredient' AND ph.entity_id = m.old_uuid;

-- Every retired spelling becomes an alias, so a recipe imported later that says
-- "onions" — or a chat agent that guesses it — still resolves.
INSERT INTO ingredient_aliases (alias, ingredient_id)
SELECT lower(btrim(m.from_name)), m.new_uuid
FROM semantic_merge_ids m
ON CONFLICT (alias) DO NOTHING;

DELETE FROM ingredients i
USING semantic_merge_ids m
WHERE i.uuid = m.old_uuid;

-- ---------------------------------------------------------------------------
-- Synonyms: names for things the book already has, under a spelling it doesn't.
-- Unlike the merges above these retire nothing, so they are safe to state up
-- front — each line is a no-op if the target ingredient isn't in the book.
-- ---------------------------------------------------------------------------
INSERT INTO ingredient_aliases (alias, ingredient_id)
SELECT a.alias, i.uuid
FROM (VALUES
  ('cilantro',        'fresh coriander'),
  ('coriander leaf',  'fresh coriander'),
  ('eggplant',        'aubergine'),
  ('zucchini',        'courgette'),
  ('scallion',        'spring onion'),
  ('scallions',       'spring onion'),
  ('green onion',     'spring onion'),
  ('asafoetida',      'hing (asafoetida)'),
  ('hing',            'hing (asafoetida)'),
  ('garbanzo beans',  'chickpeas'),
  ('rocket',          'arugula'),
  ('arugula',         'rocket'),
  ('bell pepper',     'red pepper'),
  ('capsicum',        'red pepper'),
  ('confectioners sugar', 'icing sugar'),
  ('powdered sugar',  'icing sugar'),
  ('heavy cream',     'double cream'),
  ('all purpose flour', 'plain flour'),
  ('all-purpose flour', 'plain flour'),
  ('cornstarch',      'cornflour'),
  ('aubergine',       'eggplant'),
  ('courgette',       'zucchini'),
  ('spring onion',    'scallion'),
  ('prawns',          'shrimp'),
  ('shrimp',          'prawns'),
  ('minced beef',     'ground beef'),
  ('ground beef',     'minced beef'),
  ('caster sugar',    'superfine sugar'),
  ('natural yoghurt', 'natural yogurt'),
  ('yoghurt',         'yogurt'),
  ('chilli flakes',   'chili flakes'),
  ('chili flakes',    'chilli flakes'),
  ('chillies',        'chilies'),
  ('chilies',         'chillies')
) AS a(alias, target)
INNER JOIN ingredients i ON i.canonical_name = a.target
-- An alias must never shadow a real ingredient: if the book stocks both
-- "rocket" and "arugula" as distinct rows, neither should silently resolve to
-- the other. The reciprocal pairs above exist so whichever one the book
-- actually has picks up the other as its alias — this guard drops the half that
-- would collide.
WHERE NOT EXISTS (
  SELECT 1 FROM ingredients x WHERE x.canonical_name = a.alias
)
ON CONFLICT (alias) DO NOTHING;
