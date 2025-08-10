-- name: ListRecipesWithMealPlanStatusAndLabels :many
SELECT
    r.uuid, r.name, r.description, r.cook_time, r.prep_time, r.servings, r.url,
    r.created_at, r.updated_at,
    CASE WHEN mp.recipe_id IS NOT NULL THEN true ELSE false END as is_in_meal_plan,
    r.main_photo_id
FROM recipes r
LEFT JOIN meal_plan_recipes mp ON r.uuid = mp.recipe_id
WHERE r.archived_at IS NULL
    AND (sqlc.narg('search')::text IS NULL OR r.name ILIKE '%' || sqlc.narg('search')::text || '%')
    AND (
        sqlc.arg('label_names')::text[] IS NULL
        OR r.uuid IN (
            SELECT rl2.recipe_id
            FROM recipe_label rl2
            JOIN labels l2 ON rl2.label_id = l2.uuid
            WHERE l2.name = ANY(sqlc.arg('label_names')::text[])
            GROUP BY rl2.recipe_id
            HAVING COUNT(DISTINCT l2.name) = array_length(sqlc.arg('label_names')::text[], 1)
        )
    )
ORDER BY
    CASE WHEN mp.recipe_id IS NOT NULL THEN 0 ELSE 1 END,
    r.name
LIMIT sqlc.arg('recipe_limit')
OFFSET sqlc.arg('recipe_offset');

-- name: CountRecipesWithLabels :one
SELECT COUNT(DISTINCT r.uuid)::int as count
FROM recipes r
WHERE r.archived_at IS NULL
    AND (sqlc.narg('search')::text IS NULL OR r.name ILIKE '%' || sqlc.narg('search')::text || '%')
    AND (
        sqlc.arg('label_names')::text[] IS NULL
        OR r.uuid IN (
            SELECT rl2.recipe_id
            FROM recipe_label rl2
            JOIN labels l2 ON rl2.label_id = l2.uuid
            WHERE l2.name = ANY(sqlc.arg('label_names')::text[])
            GROUP BY rl2.recipe_id
            HAVING COUNT(DISTINCT l2.name) = array_length(sqlc.arg('label_names')::text[], 1)
        )
    );
