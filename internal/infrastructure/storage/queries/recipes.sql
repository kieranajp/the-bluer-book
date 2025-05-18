-- name: GetRecipe :one
SELECT * FROM recipes WHERE uuid = $1;

-- name: ListRecipes :many
SELECT * FROM recipes ORDER BY created_at DESC;

-- name: GetRecipeWithSteps :many
SELECT
  r.uuid AS recipe_uuid,
  r.name AS recipe_name,
  r.description AS recipe_description,
  r.timing AS recipe_timing,
  r.serving_size AS recipe_serving_size,
  r.created_at AS recipe_created_at,
  r.updated_at AS recipe_updated_at,
  s.uuid AS step_uuid,
  s.recipe_id AS step_recipe_id,
  s.step_index AS step_index,
  s.description AS step_description,
  s.created_at AS step_created_at,
  s.updated_at AS step_updated_at
FROM recipes r
INNER JOIN steps s ON r.uuid = s.recipe_id
WHERE r.uuid = $1
ORDER BY s.step_index ASC;

-- name: ListRecipesWithIngredients :many
SELECT
  r.uuid AS recipe_uuid,
  r.name AS recipe_name,
  r.description AS recipe_description,
  r.timing AS recipe_timing,
  r.serving_size AS recipe_serving_size,
  r.created_at AS recipe_created_at,
  r.updated_at AS recipe_updated_at,
  i.uuid AS ingredient_uuid,
  i.name AS ingredient_name,
  ri.unit AS ingredient_unit,
  ri.quantity AS ingredient_quantity,
  ri.created_at AS ingredient_created_at,
  ri.updated_at AS ingredient_updated_at
FROM recipes r
LEFT JOIN recipe_ingredients ri ON r.uuid = ri.recipe_id
LEFT JOIN ingredients i ON ri.ingredient_id = i.uuid
ORDER BY r.created_at DESC;
