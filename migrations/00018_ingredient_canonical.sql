-- +goose Up
-- Give ingredients a canonical identity, and merge the casing duplicates that
-- accumulated for want of one.
--
-- `ingredients.name` has been the only identity an ingredient has, matched
-- exactly and case-sensitively, so the book ended up holding "Salt" and "salt",
-- "Cauliflower" and "cauliflower", "Turmeric" and "turmeric" as unrelated rows.
-- Recipes, the pantry and the shopping list all join on ingredient_id, so those
-- pairs never lined up: stocking "Salt" left "salt" on the shopping list.
--
-- Labels (00007) and units (00008) were canonicalised the same way. Ingredients
-- were the last lookup table without it, and the only one a human types at.
--
-- Display name is kept verbatim — ingredient names carry proper nouns ("MSG",
-- "BIR base gravy", "Kashmiri chilli powder") that lowercasing would mangle.
-- `canonical_name` carries identity instead.
--
-- Identity is per home (00012_tenancy): two households can each own a "milk",
-- so the canonical index and every merge below are scoped by home_id. A
-- casing-collision only ever happens within one home, because that is the only
-- uniqueness the table has ever had since tenancy.
--
-- One-way: merged ingredients cannot be unmerged, so there is no Down section
-- (same call as 00008_consolidate_units.sql).

ALTER TABLE ingredients ADD COLUMN canonical_name VARCHAR;
ALTER TABLE ingredients ADD COLUMN is_staple BOOLEAN NOT NULL DEFAULT false;

-- Trim the display name as well as deriving the canonical one: a name stored as
-- "  Turmeric  " would otherwise keep rendering with its stray whitespace long
-- after the row it collided with had been merged away.
UPDATE ingredients
SET name = btrim(name),
    canonical_name = lower(btrim(name));

-- Winner per home and canonical name: the oldest row, uuid breaking ties so the
-- choice doesn't depend on collation or physical row order.
CREATE TEMP TABLE ingredient_merge (
  old_uuid       UUID PRIMARY KEY,
  canonical_uuid UUID NOT NULL
) ON COMMIT DROP;

INSERT INTO ingredient_merge (old_uuid, canonical_uuid)
SELECT i.uuid, c.canonical_uuid
FROM ingredients i
JOIN (
  SELECT DISTINCT ON (home_id, canonical_name) home_id, canonical_name, uuid AS canonical_uuid
  FROM ingredients
  ORDER BY home_id, canonical_name, created_at ASC, uuid ASC
) c ON c.home_id = i.home_id AND c.canonical_name = i.canonical_name;

-- recipe_ingredient is keyed (home_id, recipe_id, ingredient_id, component)
-- since 00017. Rows that would land on the same key once the ids merge have to
-- go first, or the remap below hits a duplicate-key error. Keep the row already
-- pointing at the winner, else the oldest.
DELETE FROM recipe_ingredient ri
USING (
  SELECT ri2.home_id, ri2.recipe_id, ri2.ingredient_id, ri2.component,
         row_number() OVER (
           PARTITION BY ri2.home_id, ri2.recipe_id, m.canonical_uuid, ri2.component
           ORDER BY (ri2.ingredient_id = m.canonical_uuid) DESC,
                    ri2.created_at ASC, ri2.ingredient_id ASC
         ) AS rn
  FROM recipe_ingredient ri2
  JOIN ingredient_merge m ON m.old_uuid = ri2.ingredient_id
) d
WHERE ri.home_id = d.home_id
  AND ri.recipe_id = d.recipe_id
  AND ri.ingredient_id = d.ingredient_id
  AND ri.component = d.component
  AND d.rn > 1;

UPDATE recipe_ingredient ri
SET ingredient_id = m.canonical_uuid
FROM ingredient_merge m
WHERE ri.ingredient_id = m.old_uuid AND m.old_uuid <> m.canonical_uuid;

-- pantry_items is keyed (home_id, ingredient_id) since 00013_pantry_tenancy —
-- same collision, same fix, partitioned per home.
DELETE FROM pantry_items p
USING (
  SELECT p2.home_id, p2.ingredient_id,
         row_number() OVER (
           PARTITION BY p2.home_id, m.canonical_uuid
           ORDER BY (p2.ingredient_id = m.canonical_uuid) DESC,
                    p2.added_at ASC, p2.ingredient_id ASC
         ) AS rn
  FROM pantry_items p2
  JOIN ingredient_merge m ON m.old_uuid = p2.ingredient_id
) d
WHERE p.home_id = d.home_id AND p.ingredient_id = d.ingredient_id AND d.rn > 1;

UPDATE pantry_items p
SET ingredient_id = m.canonical_uuid
FROM ingredient_merge m
WHERE p.ingredient_id = m.old_uuid AND m.old_uuid <> m.canonical_uuid;

-- photos.entity_id is polymorphic with no FK. Nothing writes entity_type
-- 'ingredient' today, so this is defensive rather than load-bearing.
UPDATE photos ph
SET entity_id = m.canonical_uuid
FROM ingredient_merge m
WHERE ph.entity_type = 'ingredient'
  AND ph.entity_id = m.old_uuid
  AND m.old_uuid <> m.canonical_uuid;

DELETE FROM ingredients i
USING ingredient_merge m
WHERE i.uuid = m.old_uuid AND m.old_uuid <> m.canonical_uuid;

-- Sweep up ingredients stranded by earlier recipe edits: UpdateRecipe deletes
-- and recreates recipe_ingredient rows but never collected what it orphaned.
DELETE FROM ingredients i
WHERE NOT EXISTS (SELECT 1 FROM recipe_ingredient ri WHERE ri.ingredient_id = i.uuid)
  AND NOT EXISTS (SELECT 1 FROM pantry_items p WHERE p.ingredient_id = i.uuid);

ALTER TABLE ingredients ALTER COLUMN canonical_name SET NOT NULL;
-- Unique per home, mirroring ingredients_home_name_unique from 00012_tenancy:
-- the same display name in two homes stays two rows, but within a home "Salt"
-- and "salt" cannot both survive.
CREATE UNIQUE INDEX idx_ingredients_home_canonical_name ON ingredients (home_id, canonical_name);

-- Alternative names that resolve to an ingredient: spellings retired by a merge
-- ("onions" → onion) and hand-written synonyms ("cilantro" → coriander).
-- Deliberately left empty here — this migration only merges casing variants, and
-- the lowercased form of every name it retires is already the survivor's
-- canonical_name, so seeding from it would just restate the canonical index.
-- 00019 fills it, once the semantic merges have been reviewed.
--
-- A tenant table like any other (00012/00014): aliases are per home, because
-- identity is. A globally unique alias would let the first home to mint one
-- decide what every other home's "onions" resolves to.
CREATE TABLE ingredient_aliases (
  home_id       UUID NOT NULL DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid
                REFERENCES homes(uuid) ON DELETE CASCADE,
  alias         VARCHAR NOT NULL,
  ingredient_id UUID NOT NULL REFERENCES ingredients(uuid) ON DELETE CASCADE,
  created_at    TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (home_id, alias)
);

CREATE INDEX idx_ingredient_aliases_ingredient_id ON ingredient_aliases (ingredient_id);

ALTER TABLE ingredient_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_aliases FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON ingredient_aliases
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

-- Things assumed always in the cupboard, so they stop cluttering every "missing
-- ingredients" list (docs/pantry-inventory.md, open question 3). Toggle more
-- later via the set_ingredient_staple MCP tool.
--
-- Kept as a table, not an UPDATE-and-forget list: homes provisioned after this
-- migration (every invite) still get their staples. CreateIngredient applies
-- the default at write time; this statement is the one-off backfill for rows
-- that already exist.
CREATE TABLE staple_defaults (canonical_name VARCHAR PRIMARY KEY);

INSERT INTO staple_defaults (canonical_name) VALUES
  ('salt'), ('sea salt'), ('table salt'),
  ('pepper'), ('black pepper'), ('white pepper'),
  ('water'), ('cold water'), ('boiling water'),
  ('oil'), ('olive oil'), ('vegetable oil'), ('sunflower oil');

UPDATE ingredients SET is_staple = true
WHERE canonical_name IN (SELECT canonical_name FROM staple_defaults);