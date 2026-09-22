-- +goose Up

ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
-- FORCE also binds the table owner, which a careless deploy otherwise
-- connects as; it still does not bind a superuser or role with BYPASSRLS.
ALTER TABLE recipes FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON recipes
  -- current_setting returns '' once a session has set and cleared app.home_id;
  -- NULLIF folds that to NULL so a missing home fails closed, not a cast error.
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON steps
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE recipe_ingredient ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredient FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON recipe_ingredient
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE recipe_label ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_label FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON recipe_label
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON photos
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE meal_plan_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plan_recipes FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON meal_plan_recipes
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON ingredients
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE pantry_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pantry_items FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON pantry_items
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

ALTER TABLE shopping_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_list_items FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON shopping_list_items
  USING      (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
  WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);

-- units, labels, users, homes, home_members and invitations carry no home_id
-- and stay outside RLS: they decide which home a request acts on.

-- bluer_book_app owns no table and holds neither SUPERUSER nor BYPASSRLS, so
-- the policies above bind it; the ALTER re-asserts that for a role carried
-- over from an earlier cluster. The migrate command sets its password from
-- APP_DB_PASS on every run rather than storing it here.
-- +goose StatementBegin
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bluer_book_app') THEN
    CREATE ROLE bluer_book_app LOGIN;
  END IF;
END $$;
-- +goose StatementEnd

ALTER ROLE bluer_book_app WITH LOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;

GRANT USAGE ON SCHEMA public TO bluer_book_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO bluer_book_app;

-- Applies to tables and sequences created later too, scoped to whichever
-- role runs this migration, which is the role every migration runs as.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO bluer_book_app;

-- Excludes goose's own bookkeeping tables, which are not the app's to edit.
-- +goose StatementBegin
DO $$
BEGIN
  IF to_regclass('public.goose_db_version') IS NOT NULL THEN
    REVOKE ALL ON public.goose_db_version FROM bluer_book_app;
  END IF;
  IF to_regclass('public.goose_db_version_id_seq') IS NOT NULL THEN
    REVOKE ALL ON SEQUENCE public.goose_db_version_id_seq FROM bluer_book_app;
  END IF;
END $$;
-- +goose StatementEnd

-- +goose Down
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE USAGE, SELECT ON SEQUENCES FROM bluer_book_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM bluer_book_app;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM bluer_book_app;
REVOKE ALL ON SCHEMA public FROM bluer_book_app;

-- +goose StatementBegin
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bluer_book_app') THEN
    DROP ROLE bluer_book_app;
  END IF;
END $$;
-- +goose StatementEnd

DROP POLICY IF EXISTS home_isolation ON shopping_list_items;
DROP POLICY IF EXISTS home_isolation ON pantry_items;
DROP POLICY IF EXISTS home_isolation ON ingredients;
DROP POLICY IF EXISTS home_isolation ON meal_plan_recipes;
DROP POLICY IF EXISTS home_isolation ON photos;
DROP POLICY IF EXISTS home_isolation ON recipe_label;
DROP POLICY IF EXISTS home_isolation ON recipe_ingredient;
DROP POLICY IF EXISTS home_isolation ON steps;
DROP POLICY IF EXISTS home_isolation ON recipes;

ALTER TABLE shopping_list_items NO FORCE ROW LEVEL SECURITY;
ALTER TABLE shopping_list_items DISABLE  ROW LEVEL SECURITY;
ALTER TABLE pantry_items        NO FORCE ROW LEVEL SECURITY;
ALTER TABLE pantry_items        DISABLE  ROW LEVEL SECURITY;
ALTER TABLE ingredients         NO FORCE ROW LEVEL SECURITY;
ALTER TABLE ingredients         DISABLE  ROW LEVEL SECURITY;
ALTER TABLE meal_plan_recipes   NO FORCE ROW LEVEL SECURITY;
ALTER TABLE meal_plan_recipes   DISABLE  ROW LEVEL SECURITY;
ALTER TABLE photos              NO FORCE ROW LEVEL SECURITY;
ALTER TABLE photos              DISABLE  ROW LEVEL SECURITY;
ALTER TABLE recipe_label        NO FORCE ROW LEVEL SECURITY;
ALTER TABLE recipe_label        DISABLE  ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredient   NO FORCE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredient   DISABLE  ROW LEVEL SECURITY;
ALTER TABLE steps               NO FORCE ROW LEVEL SECURITY;
ALTER TABLE steps               DISABLE  ROW LEVEL SECURITY;
ALTER TABLE recipes             NO FORCE ROW LEVEL SECURITY;
ALTER TABLE recipes             DISABLE  ROW LEVEL SECURITY;
