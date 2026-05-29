-- name: CreateRecipe :one
INSERT INTO recipes (
    uuid,
    name,
    description,
    cook_time,
    prep_time,
    servings,
    main_photo_id,
    url,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
) RETURNING *;

-- name: CreateStep :one
INSERT INTO steps (
    uuid,
    recipe_id,
    step_order,
    description,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6
) RETURNING *;

-- name: CreateIngredient :one
INSERT INTO ingredients (
    uuid,
    name,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4
) ON CONFLICT (name) DO UPDATE SET updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: GetIngredientByName :one
SELECT * FROM ingredients WHERE name = $1;

-- name: ListIngredients :many
SELECT * FROM ingredients ORDER BY name ASC;

-- name: CreateUnit :one
INSERT INTO units (
    uuid,
    name,
    abbreviation,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5
) ON CONFLICT (name) DO UPDATE SET abbreviation = EXCLUDED.abbreviation, updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: GetUnitByName :one
SELECT * FROM units WHERE name = $1;

-- name: ListUnits :many
SELECT * FROM units ORDER BY name ASC;

-- name: CreateRecipeIngredient :one
INSERT INTO recipe_ingredient (
    recipe_id,
    ingredient_id,
    unit_id,
    quantity,
    preparation,
    component,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8
) RETURNING *;

-- name: CreateLabel :one
INSERT INTO labels (
    uuid,
    type,
    name,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5
) ON CONFLICT (type, name) DO UPDATE SET updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: GetLabelByTypeAndName :one
SELECT * FROM labels WHERE type = $1 AND name = $2;

-- name: ListLabels :many
SELECT l.type, l.name, COUNT(rl.recipe_id) AS uses
FROM labels l
LEFT JOIN recipe_label rl ON rl.label_id = l.uuid
GROUP BY l.type, l.name
ORDER BY l.type, l.name;

-- name: CreateRecipeLabel :one
INSERT INTO recipe_label (
    recipe_id,
    label_id,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4
) ON CONFLICT (recipe_id, label_id) DO NOTHING
RETURNING *;

-- name: CreatePhoto :one
INSERT INTO photos (
    uuid,
    url,
    entity_type,
    entity_id,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6
) RETURNING *;

-- name: GetPhotoByUrlAndEntity :one
SELECT * FROM photos WHERE url = $1 AND entity_type = $2 AND entity_id = $3;

-- name: GetRecipeByID :one
SELECT r.*,
       p.uuid as main_photo_uuid, p.url as main_photo_url
FROM recipes r
LEFT JOIN photos p ON r.main_photo_id = p.uuid
WHERE r.uuid = $1 AND r.archived_at IS NULL;

-- name: GetRecipeByName :one
SELECT r.*,
       p.uuid as main_photo_uuid, p.url as main_photo_url
FROM recipes r
LEFT JOIN photos p ON r.main_photo_id = p.uuid
WHERE r.name = $1 AND r.archived_at IS NULL;

-- name: ListRecipes :many
SELECT r.*,
       p.uuid as main_photo_uuid, p.url as main_photo_url,
       CASE WHEN mp.recipe_id IS NOT NULL THEN TRUE ELSE FALSE END as is_in_meal_plan
FROM recipes r
LEFT JOIN photos p ON r.main_photo_id = p.uuid
LEFT JOIN meal_plan_recipes mp ON r.uuid = mp.recipe_id
WHERE r.archived_at IS NULL
  AND ($3::text = '' OR r.name ILIKE '%' || $3 || '%' OR r.description ILIKE '%' || $3 || '%')
ORDER BY
  CASE WHEN $4::text = 'name' THEN LOWER(r.name) END ASC NULLS LAST,
  CASE WHEN $4::text = 'time' THEN COALESCE(r.prep_time, 0) + COALESCE(r.cook_time, 0) END ASC NULLS LAST,
  r.created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountRecipes :one
SELECT COUNT(*)
FROM recipes r
WHERE r.archived_at IS NULL
  AND ($1::text = '' OR r.name ILIKE '%' || $1 || '%' OR r.description ILIKE '%' || $1 || '%');

-- name: GetStepsByRecipeID :many
SELECT s.* FROM steps s
INNER JOIN recipes r ON s.recipe_id = r.uuid
WHERE s.recipe_id = $1 AND r.archived_at IS NULL
ORDER BY s.step_order ASC;

-- name: GetIngredientsByRecipeID :many
SELECT
    ri.*,
    i.name as ingredient_name,
    u.name as unit_name,
    u.abbreviation as unit_abbreviation
FROM recipe_ingredient ri
JOIN ingredients i ON ri.ingredient_id = i.uuid
LEFT JOIN units u ON ri.unit_id = u.uuid
INNER JOIN recipes r ON ri.recipe_id = r.uuid
WHERE ri.recipe_id = $1 AND r.archived_at IS NULL
ORDER BY ri.component NULLS FIRST, ri.created_at ASC;

-- name: GetLabelsByRecipeID :many
SELECT l.*
FROM recipe_label rl
JOIN labels l ON rl.label_id = l.uuid
INNER JOIN recipes r ON rl.recipe_id = r.uuid
WHERE rl.recipe_id = $1 AND r.archived_at IS NULL;

-- name: GetPhotosByRecipeID :many
SELECT p.* FROM photos p
INNER JOIN recipes r ON p.entity_id = r.uuid
WHERE p.entity_type = 'recipe' AND p.entity_id = $1 AND r.archived_at IS NULL;

-- name: DeleteStepsByRecipeID :exec
DELETE FROM steps WHERE recipe_id = $1;

-- name: DeleteRecipeIngredientsByRecipeID :exec
DELETE FROM recipe_ingredient WHERE recipe_id = $1;

-- name: DeleteRecipeLabelsByRecipeID :exec
DELETE FROM recipe_label WHERE recipe_id = $1;

-- name: DeletePhotosByRecipeID :exec
DELETE FROM photos WHERE entity_type = 'recipe' AND entity_id = $1;

-- name: DeleteStepPhotosByRecipeID :exec
DELETE FROM photos
WHERE entity_type = 'step'
  AND entity_id IN (SELECT uuid FROM steps WHERE recipe_id = $1);

-- name: UpdateRecipe :one
UPDATE recipes SET
    name = $2,
    description = $3,
    cook_time = $4,
    prep_time = $5,
    servings = $6,
    main_photo_id = $7,
    url = $8,
    updated_at = $9
WHERE uuid = $1 AND archived_at IS NULL
RETURNING *;

-- name: ArchiveRecipe :one
UPDATE recipes SET
    archived_at = $2,
    updated_at = $2
WHERE uuid = $1 AND archived_at IS NULL
RETURNING *;

-- name: RestoreRecipe :one
UPDATE recipes SET
    archived_at = NULL,
    updated_at = $2
WHERE uuid = $1 AND archived_at IS NOT NULL
RETURNING *;

-- name: GetArchivedRecipes :many
SELECT r.*,
       p.uuid as main_photo_uuid, p.url as main_photo_url
FROM recipes r
LEFT JOIN photos p ON r.main_photo_id = p.uuid
WHERE r.archived_at IS NOT NULL
ORDER BY r.archived_at DESC
LIMIT $1 OFFSET $2;

-- name: CountArchivedRecipes :one
SELECT COUNT(*) FROM recipes WHERE archived_at IS NOT NULL;
