-- +goose Up
-- home_id is denormalised onto each table so the RLS policies that follow
-- are one predicate per table.

-- units and labels stay global: shared vocabulary, not anybody's data.

-- Everything in the book today predates multitenancy, so it all belongs to the
-- founder home 00011 created.

-- Refuses to backfill if a user exists outside the founder home: they may be
-- the real owner, signed in before FOUNDER_SUBJECT was set.
-- +goose StatementBegin
DO $$
DECLARE stranded bigint;
BEGIN
  SELECT (SELECT count(*) FROM recipes) + (SELECT count(*) FROM ingredients)
    INTO stranded;

  IF stranded > 0
     AND EXISTS (SELECT 1 FROM users)
     AND NOT EXISTS (
       SELECT 1 FROM home_members
       WHERE home_id = '00000000-0000-0000-0000-000000000001'
     )
  THEN
    RAISE EXCEPTION
      'refusing to stamp % rows onto the founder home, which has no members', stranded
      USING HINT = 'Put the collection''s owner in home 00000000-0000-0000-0000-000000000001 in home_members, or point these rows at the home that owner is already in. If nobody here owns the collection, the person who does has not signed in yet — let them, with FOUNDER_SUBJECT set, then run this again.';
  END IF;
END $$;
-- +goose StatementEnd

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

-- Defaults from the per-transaction app.home_id GUC, so an unset GUC fails
-- NOT NULL instead of writing an orphan row.
ALTER TABLE recipes            ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE steps              ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE recipe_ingredient  ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE recipe_label       ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE photos             ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE meal_plan_recipes  ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;
ALTER TABLE ingredients        ALTER COLUMN home_id SET DEFAULT NULLIF(current_setting('app.home_id', true), '')::uuid;

-- ingredients_name_key (00002) was globally unique; this makes it unique per
-- home, so two households can each own a "milk", with home_id leading the index.
ALTER TABLE ingredients DROP CONSTRAINT ingredients_name_key;
ALTER TABLE ingredients ADD CONSTRAINT ingredients_home_name_unique UNIQUE (home_id, name);

CREATE INDEX idx_meal_plan_home ON meal_plan_recipes(home_id, added_at DESC);

CREATE INDEX idx_recipes_home_active   ON recipes(home_id, created_at DESC)  WHERE archived_at IS NULL;
CREATE INDEX idx_recipes_home_archived ON recipes(home_id, archived_at DESC) WHERE archived_at IS NOT NULL;

-- +goose Down
DROP INDEX IF EXISTS idx_recipes_home_active;
DROP INDEX IF EXISTS idx_recipes_home_archived;
DROP INDEX IF EXISTS idx_meal_plan_home;

-- Restoring global ingredient uniqueness only works while one home holds them
-- all, which is true of any database this Down is worth running against.
ALTER TABLE ingredients DROP CONSTRAINT IF EXISTS ingredients_home_name_unique;
ALTER TABLE ingredients ADD CONSTRAINT ingredients_name_key UNIQUE (name);

ALTER TABLE recipes            DROP COLUMN IF EXISTS home_id;
ALTER TABLE steps              DROP COLUMN IF EXISTS home_id;
ALTER TABLE recipe_ingredient  DROP COLUMN IF EXISTS home_id;
ALTER TABLE recipe_label       DROP COLUMN IF EXISTS home_id;
ALTER TABLE photos             DROP COLUMN IF EXISTS home_id;
ALTER TABLE meal_plan_recipes  DROP COLUMN IF EXISTS home_id;
ALTER TABLE ingredients        DROP COLUMN IF EXISTS home_id;
