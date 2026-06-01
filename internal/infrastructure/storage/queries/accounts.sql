-- name: GetUserBySubject :one
SELECT * FROM users WHERE subject = $1;

-- name: GetUserByUUID :one
SELECT * FROM users WHERE uuid = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;

-- name: CreateUser :one
INSERT INTO users (subject, email, display_name)
VALUES ($1, $2, $3)
RETURNING *;

-- name: CreateHome :one
INSERT INTO homes (name)
VALUES ($1)
RETURNING *;

-- name: GetHomeByID :one
SELECT * FROM homes WHERE uuid = $1;

-- name: AddHomeMember :one
INSERT INTO home_members (home_id, user_id, role)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetMostRecentHomeForUser :one
-- The user's "active" home in the absence of an explicit X-Home: the most
-- recently joined membership (ties broken by home name for determinism).
SELECT h.*
FROM homes h
INNER JOIN home_members m ON m.home_id = h.uuid
WHERE m.user_id = $1
ORDER BY m.created_at DESC, h.name ASC
LIMIT 1;

-- name: GetHomeForUserByID :one
-- Used when the client supplies X-Home. Returns the home only if the user
-- is a member, otherwise sql.ErrNoRows.
SELECT h.*
FROM homes h
INNER JOIN home_members m ON m.home_id = h.uuid
WHERE m.user_id = $1
  AND h.uuid = $2;

-- name: ListHomesForUser :many
SELECT h.*, m.role
FROM homes h
INNER JOIN home_members m ON m.home_id = h.uuid
WHERE m.user_id = $1
ORDER BY m.created_at DESC;
