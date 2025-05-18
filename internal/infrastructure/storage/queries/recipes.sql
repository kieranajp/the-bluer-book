-- name: GetRecipe :one
SELECT * FROM recipes WHERE uuid = $1;

-- name: ListRecipes :many
SELECT * FROM recipes ORDER BY created_at DESC;
