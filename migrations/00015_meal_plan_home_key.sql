-- +goose Up
-- A recipe_id-only primary key lets another home's plan entry occupy the
-- slot the owning home needed; the composite key below gives each its own.

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
