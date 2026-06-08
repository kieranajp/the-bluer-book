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

-- name: GetMembership :one
-- Returns the role the user holds in the given home, or sql.ErrNoRows if
-- they are not a member. Used for the owner-only authorisation checks.
SELECT role FROM home_members
WHERE home_id = $1 AND user_id = $2;

-- name: ListMembersForHome :many
SELECT u.uuid, u.subject, u.email, u.display_name, u.created_at, u.updated_at, m.role
FROM home_members m
INNER JOIN users u ON u.uuid = m.user_id
WHERE m.home_id = $1
ORDER BY m.created_at ASC;

-- name: CountOwnersOfHome :one
SELECT COUNT(*)::int FROM home_members
WHERE home_id = $1 AND role = 'owner';

-- name: RemoveHomeMember :exec
DELETE FROM home_members
WHERE home_id = $1 AND user_id = $2;

-- name: CreateInvitation :one
INSERT INTO invitations (home_id, email, token, role, invited_by, expires_at)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetInvitationByToken :one
SELECT * FROM invitations WHERE token = $1;

-- name: MarkInvitationAccepted :exec
UPDATE invitations SET accepted_at = now()
WHERE uuid = $1;

-- name: ListInvitationsForHome :many
SELECT * FROM invitations
WHERE home_id = $1 AND accepted_at IS NULL AND expires_at > now()
ORDER BY created_at DESC;

-- name: PurgeHome :exec
-- Destructive delete of a home. Every tenant table FKs homes(uuid) ON DELETE
-- CASCADE (see 00012 + 00013), plus home_members and invitations also CASCADE,
-- so this single DELETE sweeps recipes/steps/recipe_ingredient/recipe_label/
-- photos/meal_plan_recipes/ingredients/pantry_items/shopping_list_items along
-- with the membership and invitation rows in one statement. Must run as the
-- owner role — under FORCE RLS the app role would only see rows matching
-- app.home_id and the cascade behaviour across roles is fiddly.
DELETE FROM homes WHERE uuid = $1;

-- name: DeleteUser :exec
-- DELETE FROM users cascades home_members (ON DELETE CASCADE) and nulls
-- invitations.invited_by (ON DELETE SET NULL) for any outstanding invites the
-- user issued. Combine with PurgeHome for any home where the user was the
-- sole owner to fully scrub their footprint.
DELETE FROM users WHERE uuid = $1;
