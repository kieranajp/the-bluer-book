-- +goose Up
-- An invitation token is a bearer credential for a home, and invitations sit
-- outside row-level security because a token is looked up before either party's
-- home is known. Storing only the token's hash means read access to this table
-- no longer lets anybody join a home.
--
-- The column is replaced rather than converted: a hash cannot be derived from a
-- token nobody kept. NOT NULL with no default is deliberate — this refuses to
-- run against a table that already holds invitations instead of inventing
-- hashes for them.
ALTER TABLE invitations DROP COLUMN token;
ALTER TABLE invitations ADD COLUMN token_hash TEXT NOT NULL UNIQUE;

-- expires_at decides whether a credential is still good, and comparing a naked
-- timestamp against now() answers that differently depending on the session's
-- TimeZone. The other two follow it so the table reports one kind of time.
ALTER TABLE invitations
  ALTER COLUMN expires_at  TYPE TIMESTAMPTZ USING expires_at  AT TIME ZONE 'UTC',
  ALTER COLUMN accepted_at TYPE TIMESTAMPTZ USING accepted_at AT TIME ZONE 'UTC',
  ALTER COLUMN created_at  TYPE TIMESTAMPTZ USING created_at  AT TIME ZONE 'UTC';

-- +goose Down
-- The conversion names UTC on the way back too. Left implicit it renders in the
-- session's TimeZone, so an up-and-down round trip would move every timestamp.
ALTER TABLE invitations
  ALTER COLUMN expires_at  TYPE TIMESTAMP USING expires_at  AT TIME ZONE 'UTC',
  ALTER COLUMN accepted_at TYPE TIMESTAMP USING accepted_at AT TIME ZONE 'UTC',
  ALTER COLUMN created_at  TYPE TIMESTAMP USING created_at  AT TIME ZONE 'UTC';

-- A token cannot be recovered from its hash, so this refuses a table holding
-- invitations exactly as the Up does. Emptying it is the only way back.
ALTER TABLE invitations DROP COLUMN token_hash;
ALTER TABLE invitations ADD COLUMN token TEXT NOT NULL UNIQUE;
