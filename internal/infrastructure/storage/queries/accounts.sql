-- name: LockSubject :exec
-- Serialises provisioning for one subject. Two cold-start requests arriving
-- together would otherwise both find no user and both create a home, leaving
-- the caller a member of two. The lock is transaction-scoped, so it releases on
-- commit or rollback; hashtext maps the opaque subject onto the integer key the
-- lock takes.
SELECT pg_advisory_xact_lock(hashtext(@subject::text));

-- name: GetUserBySubject :one
SELECT * FROM users WHERE subject = @subject;

-- name: CreateUser :one
INSERT INTO users (subject, email, display_name)
VALUES (@subject, @email, @display_name)
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

-- name: CreateInvitation :one
INSERT INTO invitations (home_id, email, token, role, invited_by, expires_at)
VALUES (@home_id, @email, @token, @role, @invited_by, @expires_at)
RETURNING *;

-- name: GetInvitationByToken :one
SELECT * FROM invitations WHERE token = @token;

-- name: MarkInvitationAccepted :exec
UPDATE invitations SET accepted_at = now() WHERE uuid = @invitation_id;

-- name: ListOpenInvitationsForHome :many
SELECT * FROM invitations
WHERE home_id = @home_id AND accepted_at IS NULL AND expires_at > now()
ORDER BY created_at DESC;
