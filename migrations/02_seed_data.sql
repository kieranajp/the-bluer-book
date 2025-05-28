-- Seed Units
INSERT INTO units (name, abbreviation) VALUES
  ('gram', 'g'),
  ('kilogram', 'kg'),
  ('milliliter', 'ml'),
  ('liter', 'l'),
  ('teaspoon', 'tsp'),
  ('tablespoon', 'tbsp'),
  ('cup', 'cup'),
  ('piece', 'pc');

-- Seed Ingredients
INSERT INTO ingredients (name) VALUES
  ('Salt'),
  ('Black Pepper'),
  ('Olive Oil'),
  ('Garlic'),
  ('Onion'),
  ('Tomato'),
  ('Basil'),
  ('Pasta');

-- Seed Labels
INSERT INTO labels (name, color) VALUES
  ('Vegetarian', '#4CAF50'),
  ('Quick & Easy', '#FFC107'),
  ('Italian', '#E91E63'),
  ('Healthy', '#2196F3');

-- Seed a Sample Recipe (Simple Pasta)
INSERT INTO recipes (name, description, cook_time, prep_time, servings) VALUES
  ('Simple Garlic Pasta',
   'A quick and delicious garlic pasta dish',
   '15 minutes',
   '5 minutes',
   2);

-- Get the recipe ID for the next inserts
DO $$
DECLARE
  recipe_id UUID;
BEGIN
  SELECT uuid INTO recipe_id FROM recipes WHERE name = 'Simple Garlic Pasta';

  -- Add Steps
  INSERT INTO steps (recipe_id, step_order, description) VALUES
    (recipe_id, 1, 'Boil pasta according to package instructions'),
    (recipe_id, 2, 'Heat olive oil in a pan'),
    (recipe_id, 3, 'Add minced garlic and cook until fragrant'),
    (recipe_id, 4, 'Drain pasta and mix with garlic oil'),
    (recipe_id, 5, 'Season with salt and pepper');

  -- Add Recipe Ingredients
  INSERT INTO recipe_ingredient (recipe_id, ingredient_id, unit_id, quantity)
  SELECT 
    recipe_id,
    i.uuid,
    u.uuid,
    CASE 
      WHEN i.name = 'Pasta' THEN 200
      WHEN i.name = 'Olive Oil' THEN 2
      WHEN i.name = 'Garlic' THEN 2
      WHEN i.name = 'Salt' THEN 1
      WHEN i.name = 'Black Pepper' THEN 0.5
    END
  FROM ingredients i
  CROSS JOIN units u
  WHERE i.name IN ('Pasta', 'Olive Oil', 'Garlic', 'Salt', 'Black Pepper')
    AND u.name = CASE 
      WHEN i.name = 'Pasta' THEN 'gram'
      WHEN i.name = 'Olive Oil' THEN 'tablespoon'
      WHEN i.name = 'Garlic' THEN 'piece'
      WHEN i.name = 'Salt' THEN 'teaspoon'
      WHEN i.name = 'Black Pepper' THEN 'teaspoon'
    END;

  -- Add Recipe Labels
  INSERT INTO recipe_label (recipe_id, label_id)
  SELECT 
    recipe_id,
    l.uuid
  FROM labels l
  WHERE l.name IN ('Vegetarian', 'Quick & Easy', 'Italian');
END $$; 