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
