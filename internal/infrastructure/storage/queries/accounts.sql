-- name: LockSubject :exec
-- Serialises provisioning per subject so two concurrent requests can't each
-- create a home for it; transaction-scoped, so it releases on commit or rollback.
SELECT pg_advisory_xact_lock(hashtext(@subject::text));

-- name: GetUserBySubject :one
SELECT * FROM users WHERE subject = @subject;

-- name: GetUserByUUID :one
SELECT * FROM users WHERE uuid = @user_id;

-- name: CreateUser :one
INSERT INTO users (subject, email, display_name)
VALUES (@subject, @email, @display_name)
RETURNING *;

-- name: UpdateUserProfile :one
-- An empty value keeps what is stored: the edge forwards email and name as
-- claims, and a claim that did not arrive is silence rather than a blanking.
UPDATE users
SET email        = COALESCE(NULLIF(@email::text, ''), email),
    display_name = COALESCE(NULLIF(@display_name::text, ''), display_name),
    updated_at   = now()
WHERE subject = @subject
RETURNING *;

-- name: CreateHome :one
INSERT INTO homes (name) VALUES (@name) RETURNING *;

-- name: GetHomeByID :one
SELECT * FROM homes WHERE uuid = @home_id;

-- name: AddHomeMember :exec
-- Idempotent so a retried provision doesn't fail on the membership it already
-- wrote.
INSERT INTO home_members (home_id, user_id, role)
VALUES (@home_id, @user_id, @role)
ON CONFLICT (home_id, user_id) DO NOTHING;

-- name: GetMostRecentHomeForUser :one
-- The home a request acts on when the client names none: the most recently
-- joined membership, ties broken by name so the answer is stable.
SELECT h.* FROM homes h
INNER JOIN home_members m ON m.home_id = h.uuid
WHERE m.user_id = @user_id
ORDER BY m.created_at DESC, h.name ASC
LIMIT 1;

-- name: GetHomeForUserByID :one
-- Returns the home only if the user is a member of it, so a client naming
-- somebody else's home gets nothing rather than their data.
SELECT h.* FROM homes h
INNER JOIN home_members m ON m.home_id = h.uuid
WHERE m.user_id = @user_id AND h.uuid = @home_id;

-- name: ListMembersForHome :many
SELECT u.uuid, u.subject, u.email, u.display_name, u.created_at, u.updated_at, m.role
FROM home_members m
INNER JOIN users u ON u.uuid = m.user_id
WHERE m.home_id = @home_id
ORDER BY m.created_at ASC;

-- name: GetMembershipRole :one
SELECT role FROM home_members WHERE home_id = @home_id AND user_id = @user_id;

-- name: ListHomesForUser :many
SELECT sqlc.embed(h), m.role FROM homes h
INNER JOIN home_members m ON m.home_id = h.uuid
WHERE m.user_id = @user_id
ORDER BY m.created_at DESC, h.name ASC;

-- name: LockHome :one
-- Held for the length of a membership change, so counting owners then deleting
-- one can't race: two concurrent removals could otherwise both see two and proceed.
SELECT uuid FROM homes WHERE uuid = @home_id FOR UPDATE;

-- name: CountHomeOwners :one
SELECT count(*)::int FROM home_members WHERE home_id = @home_id AND role = 'owner';

-- name: RemoveHomeMember :execrows
DELETE FROM home_members WHERE home_id = @home_id AND user_id = @user_id;

-- name: CreateInvitation :one
INSERT INTO invitations (home_id, email, token_hash, role, invited_by, expires_at)
VALUES (@home_id, @email, @token_hash, @role, @invited_by, @expires_at)
RETURNING *;

-- name: RedeemInvitation :one
-- Spends the invitation in the statement that finds it, so a token is good
-- once; two concurrent redemptions can't both pass a check-then-write race.
UPDATE invitations
SET accepted_at = now()
WHERE token_hash = @token_hash
  AND accepted_at IS NULL
  AND expires_at > now()
RETURNING *;

-- name: GetInvitationByTokenHash :one
-- Only tells a caller why their token was refused. Redemption never reads
-- first; it goes through RedeemInvitation.
SELECT * FROM invitations WHERE token_hash = @token_hash;
