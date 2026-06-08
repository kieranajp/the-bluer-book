-- +goose Up
-- Bring the pantry feature (which landed on main while feat/multitenancy
-- was open) under the same home-isolation model the rest of the app uses
-- after 00012. pantry_items and shopping_list_items both become tenant
-- tables: stamp the founder home onto any existing rows, lock home_id
-- NOT NULL, force RLS, and re-key the case-insensitive shopping_list_item
-- uniqueness per-home.
--
-- The pantry-table RLS policy lives next to 00012's home_isolation policy
-- so the loop in 00012 doesn't need to know about future tenant tables —
-- we just add another one here.

-- 1. Add home_id (nullable for the backfill), reference homes(uuid) so a
--    home deletion cascades the pantry and custom shopping list with it.
ALTER TABLE pantry_items         ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE shopping_list_items  ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;

-- 2. Backfill: everything that exists today belongs to the founder home,
--    same as the rest of the tenant tables backfilled in 00012.
UPDATE pantry_items        SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE shopping_list_items SET home_id = '00000000-0000-0000-0000-000000000001';

ALTER TABLE pantry_items         ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE shopping_list_items  ALTER COLUMN home_id SET NOT NULL;

-- 3. The shopping list dedupes case-insensitively by name (00010 created
--    a UNIQUE index on lower(name)). That uniqueness needs to be scoped
--    per-home so two households can both add "milk".
DROP INDEX IF EXISTS idx_shopping_list_items_name_lower;
CREATE UNIQUE INDEX idx_shopping_list_items_home_name_lower
    ON shopping_list_items (home_id, lower(name));

-- 4. Re-key the pantry primary key to (home_id, ingredient_id). The
--    ingredient table is itself per-home after 00012, so an ingredient
--    uuid is already unique to one home — but the composite PK makes the
--    home-scope explicit and gives the planner a covering index for the
--    home-id-equality predicate the queries now carry.
ALTER TABLE pantry_items DROP CONSTRAINT pantry_items_pkey;
ALTER TABLE pantry_items ADD PRIMARY KEY (home_id, ingredient_id);

-- 5. Index for the home-scoped ordering paths.
CREATE INDEX idx_pantry_items_home_added_at
    ON pantry_items(home_id, added_at DESC);
CREATE INDEX idx_shopping_list_items_home_created_at
    ON shopping_list_items(home_id, created_at DESC);

-- 6. Enable + FORCE RLS with a policy keyed on app.home_id, identical in
--    shape to the one 00012 applied to the other tenant tables. The
--    application role grants from 00012 already cover these tables
--    (GRANT … ON ALL TABLES IN SCHEMA public was issued after pantry/
--    shopping_list_items already existed).
-- +goose StatementBegin
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['pantry_items', 'shopping_list_items']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    EXECUTE format($f$
      CREATE POLICY home_isolation ON %I
        USING (home_id = current_setting('app.home_id', true)::uuid)
        WITH CHECK (home_id = current_setting('app.home_id', true)::uuid);
    $f$, t);
  END LOOP;
END $$;
-- +goose StatementEnd


-- +goose Down

-- Drop policies + disable RLS on the pantry tenant tables.
-- +goose StatementBegin
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['pantry_items', 'shopping_list_items']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS home_isolation ON %I;', t);
    EXECUTE format('ALTER TABLE %I NO FORCE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY;', t);
  END LOOP;
END $$;
-- +goose StatementEnd

DROP INDEX IF EXISTS idx_pantry_items_home_added_at;
DROP INDEX IF EXISTS idx_shopping_list_items_home_created_at;
DROP INDEX IF EXISTS idx_shopping_list_items_home_name_lower;

ALTER TABLE pantry_items DROP CONSTRAINT pantry_items_pkey;
ALTER TABLE pantry_items ADD PRIMARY KEY (ingredient_id);

CREATE UNIQUE INDEX idx_shopping_list_items_name_lower
    ON shopping_list_items (lower(name));

ALTER TABLE pantry_items         DROP COLUMN IF EXISTS home_id;
ALTER TABLE shopping_list_items  DROP COLUMN IF EXISTS home_id;
