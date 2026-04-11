-- Add meal planning functionality
-- This migration adds a table to track which recipes are in the user's meal plan

CREATE TABLE meal_plan_recipes (
  recipe_id UUID REFERENCES recipes(uuid) ON DELETE CASCADE,
  added_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (recipe_id)
);

-- Index for efficient lookups and ordering by when added to meal plan
CREATE INDEX idx_meal_plan_recipes_added_at ON meal_plan_recipes(added_at DESC);
