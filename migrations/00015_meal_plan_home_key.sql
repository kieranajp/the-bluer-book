-- +goose Up
-- recipe_id is unique to one home, but a caller can still name another home's
-- id; on the recipe_id-only primary key that row occupied the slot the
-- owning home needed for its own plan entry. The composite key below gives
-- each home its own slot.

-- Rows already sitting in a home other than their recipe's are exactly those
-- collisions; a home can't see the recipe it names, so there's nothing to keep.
DELETE FROM meal_plan_recipes mp
USING recipes r
WHERE r.uuid = mp.recipe_id AND r.home_id <> mp.home_id;

ALTER TABLE meal_plan_recipes DROP CONSTRAINT meal_plan_recipes_pkey;
ALTER TABLE meal_plan_recipes ADD PRIMARY KEY (home_id, recipe_id);

-- +goose Down
ALTER TABLE meal_plan_recipes DROP CONSTRAINT meal_plan_recipes_pkey;
ALTER TABLE meal_plan_recipes ADD PRIMARY KEY (recipe_id);
