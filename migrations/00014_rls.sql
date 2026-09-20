-- +goose Up
-- The database starts enforcing. Every tenant table gets one policy keyed on
-- the same per-transaction app.home_id GUC that already fills home_id, so a
-- statement that forgets a home reads nothing and writes nothing rather than
-- crossing a boundary. Nothing in the query layer changes: the policy is the
-- predicate, applied to every statement the planner builds.
--
-- NULLIF is load-bearing. A custom GUC reverts to the empty string, not to
-- NULL, once a session has set it even once, so casting current_setting
-- straight to uuid raises 'invalid input syntax for type uuid: ""' on a pooled
-- connection whose transaction has ended. Folding '' to NULL makes the
-- comparison NULL instead, and a NULL qual excludes the row. Fail closed.
--
-- FORCE is what makes the policy mean anything: without it the table owner is
-- exempt, and the owner is exactly who a careless deploy connects as. FORCE
-- still does not bind a superuser or a role holding BYPASSRLS, which is why
-- this migration also creates bluer_book_app for the server to connect as.
--
-- units and labels carry no home and stay outside this. So do users, homes,
-- home_members and invitations: they are read to decide which home a request
-- acts on, which is a question that cannot be answered from inside the answer.

ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes FORCE  ROW LEVEL SECURITY;
CREATE POLICY home_isolation ON recipes
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

-- The role the server connects as. It owns no table and holds neither
-- SUPERUSER nor BYPASSRLS, so the policies above bind it. The ALTER runs
-- whether or not the CREATE did: a role left over from an earlier cluster with
-- either attribute would silently turn every policy above into decoration.
--
-- No password here. The migrate command sets it from APP_DB_PASS on every run,
-- so the secret stays out of a file that ships in the image.
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

-- Future tables and sequences are granted as they are created, so a later
-- migration does not have to remember. This binds to the role running right
-- now, which is the role every migration runs as.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO bluer_book_app;

-- The blanket grant above caught goose's own bookkeeping table. Migration
-- history is not the application's to edit, and nothing it does needs it.
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
