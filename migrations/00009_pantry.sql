-- +goose Up
-- Add pantry inventory functionality
-- Tracks which ingredients the user currently has at home. Presence-only by
-- design (v1): no quantity/unit — "have / don't have". Mirrors the
-- meal_plan_recipes table: single-column PK, no user_id (single-user/shared),
-- and an added_at for ordering.

CREATE TABLE pantry_items (
  ingredient_id UUID REFERENCES ingredients(uuid) ON DELETE CASCADE,
  added_at      TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (ingredient_id)
);

-- Index for ordering the pantry by when items were added.
CREATE INDEX idx_pantry_items_added_at ON pantry_items(added_at DESC);

-- +goose Down
DROP TABLE IF EXISTS pantry_items;
