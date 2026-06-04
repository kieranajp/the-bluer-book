-- +goose Up
-- Free-text shopping list items that aren't recipe ingredients — the extra
-- things you still need to buy that the meal plan can't know about (washing-up
-- liquid, bin bags, …). Added by hand or parsed from a photo of a physical
-- list. Deduped case-insensitively by name so a manual add and a scanned line
-- for the same thing don't both show up.

CREATE TABLE shopping_list_items (
  uuid       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       VARCHAR NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_shopping_list_items_name_lower ON shopping_list_items (lower(name));
CREATE INDEX idx_shopping_list_items_created_at ON shopping_list_items (created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS shopping_list_items;
