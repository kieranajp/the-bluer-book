-- +goose Up

-- 1. Founder home (backfill target). The founder *user* row and ownership
--    membership are created lazily on Kieran's first real login in Phase 3,
--    keyed off the real Kratos subject; the home exists now purely so
--    existing data can be stamped with home_id.
INSERT INTO homes (uuid, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Founder');

-- 2. Add nullable home_id to every tenant table, backfill to founder, then NOT NULL.
--    home_id is denormalised onto every table so RLS policies are trivial
--    per-table predicates rather than parent-joins.
ALTER TABLE recipes            ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE steps              ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE recipe_ingredient  ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE recipe_label       ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE photos             ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE meal_plan_recipes  ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE ingredients        ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;

UPDATE recipes            SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE steps              SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE recipe_ingredient  SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE recipe_label       SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE photos             SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE meal_plan_recipes  SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE ingredients        SET home_id = '00000000-0000-0000-0000-000000000001';

ALTER TABLE recipes            ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE steps              ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE recipe_ingredient  ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE recipe_label       ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE photos             ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE meal_plan_recipes  ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE ingredients        ALTER COLUMN home_id SET NOT NULL;

-- 3. Re-key ingredients per-home (was global UNIQUE(name) auto-named
--    ingredients_name_key by Postgres on the 00002 CREATE TABLE).
ALTER TABLE ingredients DROP CONSTRAINT ingredients_name_key;
ALTER TABLE ingredients ADD CONSTRAINT ingredients_home_name_unique UNIQUE (home_id, name);

-- 4. Meal plan scope index. PK stays on (recipe_id) — recipes are still globally
--    unique by uuid so each recipe can only be in one home's plan; the
--    index is just for the home-scoped list path.
CREATE INDEX idx_meal_plan_home ON meal_plan_recipes(home_id, added_at DESC);

-- 5. Composite indexes for the scoped read paths.
CREATE INDEX idx_recipes_home_active   ON recipes(home_id, created_at DESC)  WHERE archived_at IS NULL;
CREATE INDEX idx_recipes_home_archived ON recipes(home_id, archived_at DESC) WHERE archived_at IS NOT NULL;

-- 6. Enable + FORCE RLS on every tenant table, policy keyed on a per-request GUC.
--    units and labels are intentionally NOT touched — they remain global
--    reference data, readable/insertable by all tenants.
--
--    current_setting('app.home_id', true) with missing_ok=true returns NULL
--    when unset, so the policy denies all rows rather than erroring. This is the
--    desired fail-closed behaviour: a connection that forgot to set the GUC sees
--    nothing.
-- +goose StatementBegin
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['recipes','steps','recipe_ingredient','recipe_label','photos','meal_plan_recipes','ingredients']
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

-- 7. Non-owner application role, subject to RLS. The migration/owner role is
--    not subject to RLS (FORCE applies to non-owners). Password is injected by
--    the deploy from 1Password; created here idempotently with no password so
--    runs in CI/dev don't need to know it.
-- +goose StatementBegin
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bluer_book_app') THEN
    CREATE ROLE bluer_book_app LOGIN;
  END IF;
END $$;
-- +goose StatementEnd

GRANT USAGE ON SCHEMA public TO bluer_book_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO bluer_book_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO bluer_book_app;
-- bluer_book_app is NOT a table owner and has no BYPASSRLS, so FORCE RLS applies.


-- +goose Down

-- Drop policies + disable RLS on every tenant table.
-- +goose StatementBegin
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['recipes','steps','recipe_ingredient','recipe_label','photos','meal_plan_recipes','ingredients']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS home_isolation ON %I;', t);
    EXECUTE format('ALTER TABLE %I NO FORCE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY;', t);
  END LOOP;
END $$;
-- +goose StatementEnd

-- Revoke + drop the app role. Down only runs in dev/test, so dropping the role
-- is acceptable — prod never rolls back.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM bluer_book_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM bluer_book_app;
REVOKE ALL ON SCHEMA public FROM bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE USAGE, SELECT ON SEQUENCES FROM bluer_book_app;
-- +goose StatementBegin
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'bluer_book_app') THEN
    DROP ROLE bluer_book_app;
  END IF;
END $$;
-- +goose StatementEnd

-- Drop the new indexes + restore the ingredients global uniqueness. Safe to
-- restore UNIQUE(name) only because at this point there's still a single
-- tenant; this Down would fail after a real multi-tenant ingredient set exists.
DROP INDEX IF EXISTS idx_recipes_home_active;
DROP INDEX IF EXISTS idx_recipes_home_archived;
DROP INDEX IF EXISTS idx_meal_plan_home;

ALTER TABLE ingredients DROP CONSTRAINT IF EXISTS ingredients_home_name_unique;
ALTER TABLE ingredients ADD CONSTRAINT ingredients_name_key UNIQUE (name);

-- Drop home_id columns from every tenant table. Dropping the column also
-- drops its FK constraint, so the founder home below has no dependents.
ALTER TABLE recipes            DROP COLUMN IF EXISTS home_id;
ALTER TABLE steps              DROP COLUMN IF EXISTS home_id;
ALTER TABLE recipe_ingredient  DROP COLUMN IF EXISTS home_id;
ALTER TABLE recipe_label       DROP COLUMN IF EXISTS home_id;
ALTER TABLE photos             DROP COLUMN IF EXISTS home_id;
ALTER TABLE meal_plan_recipes  DROP COLUMN IF EXISTS home_id;
ALTER TABLE ingredients        DROP COLUMN IF EXISTS home_id;

DELETE FROM homes WHERE uuid = '00000000-0000-0000-0000-000000000001';
