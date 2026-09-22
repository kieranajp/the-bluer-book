-- +goose Up
-- Invitations sit outside row-level security since a token is looked up before
-- either party's home is known; storing only its hash keeps read access to
-- this table from letting anybody join a home.

-- Replaced, not converted: a hash can't be derived from a token nobody kept.
-- NOT NULL with no default refuses to run against a table already holding
-- invitations rather than inventing hashes for them.
ALTER TABLE invitations DROP COLUMN token;
ALTER TABLE invitations ADD COLUMN token_hash TEXT NOT NULL UNIQUE;

-- expires_at decides whether a credential is still good; comparing a naked
-- timestamp against now() depends on the session's TimeZone. The others follow it.
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
