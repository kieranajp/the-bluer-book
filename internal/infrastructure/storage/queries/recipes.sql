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
) ON CONFLICT (uuid) DO UPDATE SET name = EXCLUDED.name, updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: GetIngredientByName :one
SELECT * FROM ingredients WHERE name = $1;

-- name: CreateUnit :one
INSERT INTO units (
    uuid,
    name,
    abbreviation,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5
) ON CONFLICT (uuid) DO UPDATE SET name = EXCLUDED.name, abbreviation = EXCLUDED.abbreviation, updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: GetUnitByName :one
SELECT * FROM units WHERE name = $1;

-- name: CreateRecipeIngredient :one
INSERT INTO recipe_ingredient (
    recipe_id,
    ingredient_id,
    unit_id,
    quantity,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6
) RETURNING *;

-- name: CreateLabel :one
INSERT INTO labels (
    uuid,
    name,
    color,
    created_at,
    updated_at
) VALUES (
    $1, $2, $3, $4, $5
) ON CONFLICT (uuid) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color, updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: GetLabelByName :one
SELECT * FROM labels WHERE name = $1;

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
WHERE r.uuid = $1;

-- name: GetRecipeByName :one
SELECT r.*,
       p.uuid as main_photo_uuid, p.url as main_photo_url
FROM recipes r
LEFT JOIN photos p ON r.main_photo_id = p.uuid
WHERE r.name = $1;

-- name: ListRecipes :many
SELECT r.*,
       p.uuid as main_photo_uuid, p.url as main_photo_url
FROM recipes r
LEFT JOIN photos p ON r.main_photo_id = p.uuid
WHERE ($3::text = '' OR r.name ILIKE '%' || $3 || '%' OR r.description ILIKE '%' || $3 || '%')
ORDER BY r.created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountRecipes :one
SELECT COUNT(*)
FROM recipes r
WHERE ($1::text = '' OR r.name ILIKE '%' || $1 || '%' OR r.description ILIKE '%' || $1 || '%');

-- name: GetStepsByRecipeID :many
SELECT * FROM steps
WHERE recipe_id = $1
ORDER BY step_order ASC;

-- name: GetIngredientsByRecipeID :many
SELECT
    ri.*,
    i.name as ingredient_name,
    u.name as unit_name,
    u.abbreviation as unit_abbreviation
FROM recipe_ingredient ri
JOIN ingredients i ON ri.ingredient_id = i.uuid
LEFT JOIN units u ON ri.unit_id = u.uuid
WHERE ri.recipe_id = $1;

-- name: GetLabelsByRecipeID :many
SELECT l.*
FROM recipe_label rl
JOIN labels l ON rl.label_id = l.uuid
WHERE rl.recipe_id = $1;

-- name: GetPhotosByRecipeID :many
SELECT * FROM photos
WHERE entity_type = 'recipe' AND entity_id = $1;
