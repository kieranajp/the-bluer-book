-- name: AddToMealPlan :exec
INSERT INTO meal_plan_recipes (recipe_id)
VALUES ($1)
ON CONFLICT (recipe_id) DO NOTHING;

-- name: RemoveFromMealPlan :exec
DELETE FROM meal_plan_recipes
WHERE recipe_id = $1;

-- name: ListMealPlanRecipes :many
SELECT
  r.uuid,
  r.name,
  r.description,
  r.cook_time,
  r.prep_time,
  r.servings,
  p.uuid as main_photo_uuid,
  p.url as main_photo_url,
  r.url,
  r.created_at,
  r.updated_at,
  r.archived_at,
  TRUE as is_in_meal_plan
FROM recipes r
INNER JOIN meal_plan_recipes mp ON r.uuid = mp.recipe_id
LEFT JOIN photos p ON r.main_photo_id = p.uuid
WHERE r.archived_at IS NULL
ORDER BY mp.added_at DESC;
