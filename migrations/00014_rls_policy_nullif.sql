-- +goose Up
-- Custom Postgres GUCs default to an empty string '' once they've been
-- referenced in a session, not NULL. SET LOCAL inside a transaction
-- leaves them at '' after commit on the same pooled connection. The
-- original home_isolation policies cast current_setting(...) directly
-- to uuid, so a subsequent query on that connection — outside any
-- transaction with a fresh SET LOCAL — hits 'invalid input syntax for
-- type uuid: ""' instead of just filtering rows.
--
-- This migration redefines every home_isolation policy to wrap the GUC
-- read in NULLIF, so an empty string folds to NULL and the cast to
-- uuid succeeds (the comparison home_id = NULL then evaluates to
-- NULL, which excludes the row — the fail-closed behaviour we wanted
-- all along). FORCE RLS + the GRANTs are unchanged.

-- +goose StatementBegin
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'recipes','steps','recipe_ingredient','recipe_label','photos',
    'meal_plan_recipes','ingredients','pantry_items','shopping_list_items'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS home_isolation ON %I;', t);
    EXECUTE format($f$
      CREATE POLICY home_isolation ON %I
        USING (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid)
        WITH CHECK (home_id = NULLIF(current_setting('app.home_id', true), '')::uuid);
    $f$, t);
  END LOOP;
END $$;
-- +goose StatementEnd


-- +goose Down
-- +goose StatementBegin
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'recipes','steps','recipe_ingredient','recipe_label','photos',
    'meal_plan_recipes','ingredients','pantry_items','shopping_list_items'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS home_isolation ON %I;', t);
    EXECUTE format($f$
      CREATE POLICY home_isolation ON %I
        USING (home_id = current_setting('app.home_id', true)::uuid)
        WITH CHECK (home_id = current_setting('app.home_id', true)::uuid);
    $f$, t);
  END LOOP;
END $$;
-- +goose StatementEnd
