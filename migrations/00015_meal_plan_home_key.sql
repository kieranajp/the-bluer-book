-- +goose Up
-- The meal plan is keyed per home, like the pantry.
--
-- 00012 left the primary key on recipe_id alone, reasoning that a recipe uuid
-- belongs to exactly one home and so can only ever appear in that home's plan.
-- That holds for a uuid a home read out of its own collection, and not for one
-- supplied by the caller. POST /api/recipes/{id}/meal-plan passes the id
-- straight through, and PostgreSQL checks uniqueness and foreign keys with row
-- security switched off, so a home naming another home's recipe id inserted a
-- row against it: the foreign key resolved to a recipe the policy hides, and
-- the row took the caller's home from the column default.
--
-- The row itself was inert — every read joins recipes, which is scoped — but it
-- occupied the key. The owning home adding its own recipe to its own plan then
-- hit ON CONFLICT (recipe_id) DO NOTHING against a row it cannot see, and got a
-- success and no plan entry, for good. A composite key gives each home its own
-- slot, so the two rows no longer collide.

-- Any row already sitting in a home other than its recipe's is one of those.
-- There is nothing to keep: a home cannot see the recipe it names.
DELETE FROM meal_plan_recipes mp
USING recipes r
WHERE r.uuid = mp.recipe_id AND r.home_id <> mp.home_id;

ALTER TABLE meal_plan_recipes DROP CONSTRAINT meal_plan_recipes_pkey;
ALTER TABLE meal_plan_recipes ADD PRIMARY KEY (home_id, recipe_id);

-- +goose Down
ALTER TABLE meal_plan_recipes DROP CONSTRAINT meal_plan_recipes_pkey;
ALTER TABLE meal_plan_recipes ADD PRIMARY KEY (recipe_id);
