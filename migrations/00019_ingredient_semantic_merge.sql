-- +goose Up
-- Apply the reviewed semantic ingredient merges, and seed the synonym aliases.
--
-- 00018 merged casing variants, which needs no judgement. What is left needs
-- plenty: "onions" and "onion" are the same shopping item, "garlic cloves" is
-- "garlic" with a qualifier that belongs on the recipe line, and "ground cumin"
-- and "cumin seeds" are emphatically NOT the same thing however similar they
-- look. That call can't be made mechanically, and it can't be made safely by a
-- model unsupervised either.
--
-- So the mapping below is data, reviewed by a human (Edele, 2026-09-22), and
-- this migration is the deterministic machinery that applies it. To produce it:
--
--   go run . propose-ingredient-merges --dry-run     # inspect
--   go run . propose-ingredient-merges               # writes migrations/data/ingredient_merges.json
--
-- then read the JSON, delete anything you disagree with, and transcribe what
-- survives into the INSERT below. The command validates its own output — it
-- drops merges that cross a form boundary, chain, or name an ingredient that
-- doesn't exist — but it proposes; you decide.
--
-- Always map to the FINAL canonical — a from_name that is also another line's
-- to_name forms a chain this migration does not follow (one-hop remaps leave
-- the middle row referenced, which the final DELETE then trips over).
--
-- One-way, like 00008 and 00018: no Down section.

CREATE TEMP TABLE semantic_merge (
  from_name   VARCHAR NOT NULL,
  to_name     VARCHAR NOT NULL,
  preparation VARCHAR NOT NULL DEFAULT ''
) ON COMMIT DROP;

-- ---------------------------------------------------------------------------
-- Reviewed merges, canonical names only, per home. The count qualifier on a
-- name ("garlic cloves") is handled at write time by resolveIngredient — the
-- mapping here only retires rows that already exist. Preparation stays empty:
-- how an ingredient was cut is the recipe's business, not the book's.
-- ---------------------------------------------------------------------------
INSERT INTO semantic_merge (from_name, to_name) VALUES
  -- garlic family: the name is the ingredient; the count lives on the line.
  -- "fresh garlic" is deliberately absent — "fresh" is a form word (fresh vs
  -- dried garlic are different items), so propose-ingredient-merges refuses
  -- the merge and the qualifier stays in the name.
  ('garlic clove',  'garlic'),
  ('garlic cloves', 'garlic'),
  -- plurals -> singular (quantity drives display plural in the app)
  ('onions',                     'onion'),
  ('red onions',                 'red onion'),
  ('white onions',               'white onion'),
  -- "spring onions" is the canonical this book already stores; the singular
  -- folds into it rather than the usual plural->singular rule.
  ('spring onion',               'spring onions'),
  ('carrots',                    'carrot'),
  ('eggs',                       'egg'),
  ('large eggs',                 'large egg'),
  ('free-range eggs',            'free-range egg'),
  ('egg yolks',                  'egg yolk'),
  ('tomatoes',                   'tomato'),
  ('potatoes',                   'potato'),
  ('lemons',                     'lemon'),
  ('leeks',                      'leek'),
  ('shallots',                   'shallot'),
  ('apples',                     'apple'),
  ('courgettes',                 'courgette'),
  ('pita breads',                'pita bread'),
  ('chicken breasts',            'chicken breast'),
  ('bell peppers',               'bell pepper'),
  ('red bell peppers',           'red bell pepper'),
  ('red peppers',                'red pepper'),
  ('serrano peppers',            'serrano pepper'),
  -- synonyms: one shopping item, whatever it is called (UK spellings win)
  ('scallions',                  'spring onions'),
  ('green onion',                'spring onions'),
  ('green onions',               'spring onions'),
  ('eggplants',                  'aubergine'),
  ('eggplant',                   'aubergine'),
  ('zucchini',                   'courgette'),
  ('small zucchinis',            'small courgette'),
  ('greek yogurt',               'greek yoghurt'),
  -- "chili flakes" is the spelling this book's recipes use; the UK-style
  -- spelling retires into it (opposite of the usual UK-wins rule, driven by
  -- what the book already has).
  ('chilli flakes',              'chili flakes');

-- ---------------------------------------------------------------------------
-- Synonyms: names for things the book already has, under a spelling it doesn't.
-- Unlike the merges above these retire nothing, so they are safe to state up
-- front — each line is a no-op if the target ingredient isn't in the book.
-- Per home: the alias table is a tenant table, so a synonym attaches in every
-- home whose target exists there. "cilantro" is deliberately absent from the
-- merges — UK usage is coriander, and it points at whichever coriander row the
-- home actually has.
-- ---------------------------------------------------------------------------
INSERT INTO ingredient_aliases (home_id, alias, ingredient_id)
SELECT i.home_id, a.alias, i.uuid
FROM (VALUES
  ('cilantro',          'coriander'),
  ('coriander leaf',    'coriander'),
  ('coriander leaves',  'coriander'),
  ('coriander',         'fresh coriander'),
  ('coriander',         'ground coriander'),
  ('coriander seed',    'coriander seeds'),
  ('eggplant',          'aubergine'),
  ('zucchini',          'courgette'),
  ('scallion',          'spring onions'),
  ('scallions',         'spring onions'),
  ('asafoetida',        'hing (asafoetida)'),
  ('hing',              'hing (asafoetida)'),
  ('garbanzo beans',    'chickpeas'),
  ('rocket',            'arugula'),
  ('arugula',           'rocket'),
  ('bell pepper',       'red pepper'),
  ('capsicum',          'red pepper'),
  ('confectioners sugar', 'icing sugar'),
  ('powdered sugar',    'icing sugar'),
  ('heavy cream',       'double cream'),
  ('all purpose flour', 'plain flour'),
  ('all-purpose flour', 'plain flour'),
  ('cornstarch',        'cornflour'),
  ('prawns',            'shrimp'),
  ('shrimp',            'prawns'),
  ('minced beef',       'ground beef'),
  ('ground beef',       'minced beef'),
  ('caster sugar',      'superfine sugar'),
  ('natural yoghurt',   'natural yogurt'),
  ('yoghurt',           'yogurt'),
  ('chillies',          'chilies'),
  ('chilies',           'chillies')
) AS a(alias, target)
INNER JOIN ingredients i ON i.canonical_name = a.target
-- An alias must never shadow a real ingredient: if the book stocks both
-- "rocket" and "arugula" as distinct rows, neither should silently resolve to
-- the other. The reciprocal pairs above exist so whichever one the book
-- actually has picks up the other as its alias — this guard drops the half that
-- would collide.
WHERE NOT EXISTS (
  SELECT 1 FROM ingredients x WHERE x.home_id = i.home_id AND x.canonical_name = a.alias
)
ON CONFLICT (home_id, alias) DO NOTHING;

-- Resolve names to rows, per home — a merge only applies where BOTH sides
-- exist in the same home, dropping any line whose ingredients no longer exist
-- so a stale mapping degrades to a no-op instead of failing the deploy.
CREATE TEMP TABLE semantic_merge_ids (
  old_uuid    UUID NOT NULL,
  new_uuid    UUID NOT NULL,
  from_name   VARCHAR NOT NULL,
  home_id     UUID NOT NULL
) ON COMMIT DROP;

INSERT INTO semantic_merge_ids (old_uuid, new_uuid, from_name, home_id)
SELECT old_i.uuid, new_i.uuid, m.from_name, old_i.home_id
FROM semantic_merge m
INNER JOIN ingredients new_i ON new_i.canonical_name = lower(btrim(m.to_name))
INNER JOIN ingredients old_i ON old_i.home_id = new_i.home_id
                           AND old_i.canonical_name = lower(btrim(m.from_name))
WHERE old_i.uuid <> new_i.uuid;

-- Same dedupe-before-remap as 00018: recipe_ingredient keys on
-- (home_id, recipe_id, ingredient_id, component) and pantry_items on
-- (home_id, ingredient_id), so collisions have to be resolved before the ids
-- move. Both tables carry home_id, and a merge never crosses homes (the join
-- above is same-home), so the partition stays per-home throughout.
DELETE FROM recipe_ingredient ri
USING (
  SELECT ri2.home_id, ri2.recipe_id, ri2.ingredient_id, ri2.component,
         row_number() OVER (
           PARTITION BY ri2.home_id,
                        ri2.recipe_id,
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
WHERE ri.home_id = d.home_id
  AND ri.recipe_id = d.recipe_id
  AND ri.ingredient_id = d.ingredient_id
  AND ri.component = d.component
  AND d.rn > 1;

UPDATE recipe_ingredient ri
SET ingredient_id = m.new_uuid
FROM semantic_merge_ids m
WHERE ri.ingredient_id = m.old_uuid;

DELETE FROM pantry_items p
USING (
  SELECT p2.home_id, p2.ingredient_id,
         row_number() OVER (
           PARTITION BY p2.home_id,
                        COALESCE(m.new_uuid, p2.ingredient_id)
           ORDER BY (m.new_uuid IS NULL) DESC, p2.added_at ASC, p2.ingredient_id ASC
         ) AS rn
  FROM pantry_items p2
  LEFT JOIN semantic_merge_ids m ON m.old_uuid = p2.ingredient_id
  WHERE EXISTS (
    SELECT 1 FROM semantic_merge_ids s
    WHERE s.old_uuid = p2.ingredient_id OR s.new_uuid = p2.ingredient_id
  )
) d
WHERE p.home_id = d.home_id AND p.ingredient_id = d.ingredient_id AND d.rn > 1;

UPDATE pantry_items p
SET ingredient_id = m.new_uuid
FROM semantic_merge_ids m
WHERE p.ingredient_id = m.old_uuid;

UPDATE photos ph
SET entity_id = m.new_uuid
FROM semantic_merge_ids m
WHERE ph.entity_type = 'ingredient' AND ph.entity_id = m.old_uuid;

-- Every retired spelling becomes an alias, so a recipe imported later that says
-- "onions" — or a chat agent that guesses it — still resolves. Per home: the
-- alias table is a tenant table, so each home that holds both sides of a merge
-- gets its own alias row.
INSERT INTO ingredient_aliases (home_id, alias, ingredient_id)
SELECT m.home_id, lower(btrim(m.from_name)), m.new_uuid
FROM semantic_merge_ids m
ON CONFLICT (home_id, alias) DO NOTHING;

DELETE FROM ingredients i
USING semantic_merge_ids m
WHERE i.uuid = m.old_uuid;