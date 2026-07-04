-- name: AddToMealPlan :exec
INSERT INTO meal_plan_recipes (recipe_id, home_id)
VALUES ($1, current_setting('app.home_id', true)::uuid)
ON CONFLICT (recipe_id) DO NOTHING;

-- name: RemoveFromMealPlan :exec
DELETE FROM meal_plan_recipes
WHERE recipe_id = $1
  AND home_id = current_setting('app.home_id', true)::uuid;

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
INNER JOIN meal_plan_recipes mp
  ON r.uuid = mp.recipe_id
 AND mp.home_id = current_setting('app.home_id', true)::uuid
LEFT JOIN photos p
  ON r.main_photo_id = p.uuid
 AND p.home_id = current_setting('app.home_id', true)::uuid
WHERE r.archived_at IS NULL
  AND r.home_id = current_setting('app.home_id', true)::uuid
ORDER BY mp.added_at DESC;
