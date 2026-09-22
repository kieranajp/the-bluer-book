-- +goose Up
-- Pantry and shopping list get the same home_id-from-GUC model as the rest of
-- the book, backfilled to the founder home for pre-existing rows.

-- Unlike 00012, this backfill is unguarded: a database holding only a pantry
-- has nothing for 00012's guard to see. Same bet as a first deploy, and the
-- pantry is cheap to rebuild where the recipe collection isn't.

ALTER TABLE pantry_items         ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE shopping_list_items  ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;

UPDATE pantry_items        SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE shopping_list_items SET home_id = '00000000-0000-0000-0000-000000000001';

ALTER TABLE pantry_items         ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE shopping_list_items  ALTER COLUMN home_id SET NOT NULL;

ALTER TABLE pantry_items         ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE shopping_list_items  ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;

-- The pantry is keyed per home, so the same ingredient row can be stocked in
-- one household and not another.
ALTER TABLE pantry_items DROP CONSTRAINT pantry_items_pkey;
ALTER TABLE pantry_items ADD PRIMARY KEY (home_id, ingredient_id);

-- The shopping list dedupes case-insensitively (00010). That uniqueness is now
-- per home, so two households can each write down milk.
DROP INDEX IF EXISTS idx_shopping_list_items_name_lower;
CREATE UNIQUE INDEX idx_shopping_list_items_home_name_lower
    ON shopping_list_items (home_id, lower(name));

CREATE INDEX idx_pantry_items_home_added_at
    ON pantry_items(home_id, added_at DESC);
CREATE INDEX idx_shopping_list_items_home_created_at
    ON shopping_list_items(home_id, created_at DESC);

-- +goose Down
DROP INDEX IF EXISTS idx_pantry_items_home_added_at;
DROP INDEX IF EXISTS idx_shopping_list_items_home_created_at;
DROP INDEX IF EXISTS idx_shopping_list_items_home_name_lower;

CREATE UNIQUE INDEX idx_shopping_list_items_name_lower
    ON shopping_list_items (lower(name));

ALTER TABLE pantry_items DROP CONSTRAINT pantry_items_pkey;
ALTER TABLE pantry_items ADD PRIMARY KEY (ingredient_id);

ALTER TABLE pantry_items         DROP COLUMN IF EXISTS home_id;
ALTER TABLE shopping_list_items  DROP COLUMN IF EXISTS home_id;
